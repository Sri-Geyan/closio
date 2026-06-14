import express from 'express';
import cors from 'cors';
import { createServer } from 'http';
import { Server } from 'socket.io';
import { PrismaClient } from '@prisma/client';
import dotenv from 'dotenv';
import * as admin from 'firebase-admin';
import { generateSecret, generateURI, verifySync } from 'otplib';
import QRCode from 'qrcode';

import { authenticateToken } from './middlewares/auth';
import eventsRouter from './routes/events';
import hubsRouter from './routes/hubs';
import splitsRouter from './routes/splits';
import pollsRouter from './routes/polls';
import jukeboxRouter from './routes/jukebox';
import aiRouter from './routes/ai';
import gamingRouter from './routes/gaming';
import zomatoRouter from './routes/zomato';
import locationsRouter from './routes/locations';

dotenv.config();

// Initialize Firebase Admin (will throw error or warn if no credentials provided)
try {
  admin.initializeApp();
} catch (e) {
  console.warn("Firebase Admin could not be initialized. Check GOOGLE_APPLICATION_CREDENTIALS");
}

export { admin };

const app = express();
const httpServer = createServer(app);
const io = new Server(httpServer, {
  cors: {
    origin: '*', // For MVP
  }
});

const prisma = new PrismaClient();

app.use(cors());
app.use(express.json());

// Basic health check
app.get('/health', (req, res) => {
  res.json({ status: 'ok', timestamp: new Date() });
});

// Sync user from Supabase auth
app.post('/users/sync', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user.sub;
    const { username, avatarUrl, fcmToken, upiId, bio } = req.body;
    
    let user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) {
      user = await prisma.user.create({
        data: { supabaseId, username, avatarUrl, fcmToken, upiId, bio }
      });
    } else {
      user = await prisma.user.update({
        where: { supabaseId },
        data: { username, avatarUrl, fcmToken, upiId, bio }
      });
    }
    res.json(user);
  } catch (error: any) {
    console.error(error);
    if (error.code === 'P2002' && error.meta?.target?.includes('username')) {
      return res.status(400).json({ error: 'Username is already taken' });
    }
    res.status(500).json({ error: 'Failed to sync user' });
  }
});

// Get current user profile
app.get('/users/me', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user.sub;
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch user' });
  }
});

// TOTP Setup
app.post('/users/me/totp/setup', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user.sub;
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const secret = generateSecret();
    const otpauthUrl = generateURI({ label: user.username, issuer: 'Closio', secret });
    const qrCodeImage = await QRCode.toDataURL(otpauthUrl);

    // Save temporary secret (do not enable yet)
    await prisma.user.update({
      where: { supabaseId },
      data: { totpSecret: secret }
    });

    res.json({ secret, qrCodeImage });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to setup TOTP' });
  }
});

// TOTP Verify & Enable
app.post('/users/me/totp/verify', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user.sub;
    const { token } = req.body;
    
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user || !user.totpSecret) return res.status(400).json({ error: 'TOTP not setup' });

    const isValid = verifySync({ token, secret: user.totpSecret });
    
    if (isValid) {
      await prisma.user.update({
        where: { supabaseId },
        data: { isTotpEnabled: true }
      });
      res.json({ success: true });
    } else {
      res.status(400).json({ error: 'Invalid token' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to verify TOTP' });
  }
});

// TOTP Validate (Login Hook)
app.post('/users/me/totp/validate', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user.sub;
    const { token } = req.body;
    
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user || !user.isTotpEnabled || !user.totpSecret) {
      return res.status(400).json({ error: 'TOTP not enabled' });
    }

    const isValid = verifySync({ token, secret: user.totpSecret });
    
    if (isValid) {
      // In a real app, you would issue a custom JWT or session cookie here.
      res.json({ success: true, mfaVerified: true });
    } else {
      res.status(401).json({ error: 'Invalid TOTP token' });
    }
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to validate TOTP' });
  }
});

// Data Export (GDPR)
app.get('/users/me/export', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user.sub;
    const user = await prisma.user.findUnique({
      where: { supabaseId },
      include: {
        hubMemberships: { include: { hub: true } },
        eventAttendances: true,
        splitParticipations: true,
        loginActivities: true,
      }
    });

    if (!user) return res.status(404).json({ error: 'User not found' });

    const exportData = {
      profile: {
        id: user.id,
        username: user.username,
        bio: user.bio,
        createdAt: user.createdAt,
      },
      hubs: user.hubMemberships.map(hm => hm.hub),
      events: user.eventAttendances,
      splits: user.splitParticipations,
      activity: user.loginActivities,
    };

    res.json(exportData);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to export data' });
  }
});

// Soft Delete Account
app.delete('/users/me', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user.sub;
    
    // Set deletedAt flag for 30-day wipe window
    await prisma.user.update({
      where: { supabaseId },
      data: { deletedAt: new Date() }
    });

    // In a real app, also disable Supabase account or revoke sessions here
    res.json({ success: true, message: 'Account scheduled for deletion in 30 days.' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to delete account' });
  }
});

app.use('/events', eventsRouter);
app.use('/hubs', hubsRouter);
app.use('/splits', splitsRouter);
app.use('/polls', pollsRouter);
app.use('/jukebox', jukeboxRouter);
app.use('/ai', aiRouter);
app.use('/gaming', gamingRouter);
app.use('/zomato', zomatoRouter);
app.use('/locations', locationsRouter);

// Realtime Chat & Attendance WebSockets
io.on('connection', (socket) => {
  console.log('User connected:', socket.id);

  socket.on('join_hub', (hubId) => {
    socket.join(`hub_${hubId}`);
    console.log(`Socket ${socket.id} joined hub ${hubId}`);
  });

  socket.on('send_message', async (data) => {
    const { hubId, senderId, text, mediaUrl, type } = data;
    try {
      // Save message to DB
      const message = await prisma.message.create({
        data: { hubId, senderId, text, mediaUrl, type },
        include: { sender: true }
      });
      // Broadcast to hub
      io.to(`hub_${hubId}`).emit('new_message', message);
      
      // Publish to AI Layer
      redisService.publishChatMessage(senderId, hubId, text || '');
      redisService.publishUserActivity(senderId, 'send_message', hubId);
    } catch (error) {
      console.error('Error sending message:', error);
    }
  });

  socket.on('vote_poll', async (data) => {
    // Poll voting is now handled via REST in /polls routes. 
    // This socket event is kept for backwards compatibility or can broadcast poll updates.
  });

  // --- Voice Rooms (WebRTC Signaling) ---
  socket.on('join_voice_room', (roomId, userId) => {
    socket.join(`voice_${roomId}`);
    socket.to(`voice_${roomId}`).emit('user_joined_voice', { userId, socketId: socket.id });
    console.log(`User ${userId} (${socket.id}) joined voice room ${roomId}`);
  });

  socket.on('leave_voice_room', (roomId, userId) => {
    socket.leave(`voice_${roomId}`);
    socket.to(`voice_${roomId}`).emit('user_left_voice', { userId, socketId: socket.id });
  });

  socket.on('webrtc_offer', (data) => {
    const { targetSocketId, offer, callerId } = data;
    io.to(targetSocketId).emit('webrtc_offer', { offer, callerId, socketId: socket.id });
  });

  socket.on('webrtc_answer', (data) => {
    const { targetSocketId, answer, answererId } = data;
    io.to(targetSocketId).emit('webrtc_answer', { answer, answererId, socketId: socket.id });
  });

  socket.on('webrtc_ice_candidate', (data) => {
    const { targetSocketId, candidate } = data;
    io.to(targetSocketId).emit('webrtc_ice_candidate', { candidate, socketId: socket.id });
  });

  // --- Jukebox (Spotify) ---
  socket.on('jukebox_queue_track', async (data) => {
    const { hubId, sessionId, addedById, title, artist, albumArt, spotifyUrl } = data;
    try {
      // The frontend currently passes the Supabase auth ID for addedById
      const user = await prisma.user.findUnique({ where: { supabaseId: addedById } });
      if (!user) {
        console.error('User not found for jukebox_queue_track:', addedById);
        return;
      }
      const track = await prisma.jukeboxTrack.create({
        data: { sessionId, addedById: user.id, title, artist, albumArt, spotifyUrl },
        include: { addedBy: { select: { id: true, username: true } } }
      });
      io.to(`hub_${hubId}`).emit('jukebox_track_added', track);
    } catch (e) {
      console.error('Error queuing track:', e);
    }
  });

  socket.on('jukebox_vote_track', async (data) => {
    const { hubId, trackId, voteChange } = data; // voteChange is 1 or -1
    try {
      const track = await prisma.jukeboxTrack.update({
        where: { id: trackId },
        data: { votes: { increment: voteChange } },
        include: { addedBy: { select: { id: true, username: true } } }
      });
      io.to(`hub_${hubId}`).emit('jukebox_track_updated', track);
    } catch (e) {
      console.error('Error voting on track:', e);
    }
  });

  socket.on('jukebox_now_playing', (data) => {
    const { hubId, track, progressMs, isPlaying } = data;
    io.to(`hub_${hubId}`).emit('jukebox_now_playing', { track, progressMs, isPlaying });
  });

  socket.on('jukebox_ended', (hubId) => {
    io.to(`hub_${hubId}`).emit('jukebox_ended');
  });

  // --- Live Location Sharing ---
  socket.on('update_location', (data) => {
    const { hubId, userId, latitude, longitude } = data;
    // Broadcast location to hub members
    io.to(`hub_${hubId}`).emit('location_update', { userId, latitude, longitude });
    
    // Publish to AI Layer for spatial clustering
    redisService.publishLocationUpdate(userId, latitude, longitude);
  });

  socket.on('disconnect', () => {
    console.log('User disconnected:', socket.id);
  });
});
// Nodemon trigger comment

import { startVanishWorker } from './workers/vanishWorker';
import { redisService } from './services/redisService';
import { discordService } from './services/discordService';

const PORT = process.env.PORT || 3000;
httpServer.listen(PORT, async () => {
  console.log(`Closio backend running on port ${PORT}`);
  startVanishWorker();
  await redisService.connect();
  await discordService.login(process.env.DISCORD_BOT_TOKEN || '');
});
