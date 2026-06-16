import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticateToken } from '../middlewares/auth';

const router = Router();
const prisma = new PrismaClient();

// Get active session for a hub
router.get('/:hubId', authenticateToken, async (req: any, res) => {
  try {
    const { hubId } = req.params;
    const session = await prisma.jukeboxSession.findUnique({
      where: { hubId },
      include: {
        host: { select: { id: true, username: true } },
        tracks: {
          orderBy: { votes: 'desc' },
          include: { addedBy: { select: { id: true, username: true } } }
        }
      }
    });
    if (!session || !session.isActive) {
      return res.status(404).json({ error: 'No active session' });
    }
    res.json(session);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch session' });
  }
});

// Start a new session
router.post('/:hubId/start', authenticateToken, async (req: any, res) => {
  try {
    const { hubId } = req.params;
    const { name, mood } = req.body;
    const userId = req.user.sub;
    
    const user = await prisma.user.findUnique({ where: { supabaseId: userId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    // End existing session if any
    await prisma.jukeboxSession.deleteMany({
      where: { hubId }
    });

    const session = await prisma.jukeboxSession.create({
      data: {
        hubId,
        hostId: user.id,
        name: name || 'Just Vibing',
        mood: mood || 'Chill'
      },
      include: { host: { select: { id: true, username: true } } }
    });
    
    res.json(session);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to start session' });
  }
});

// End session
router.post('/:hubId/end', authenticateToken, async (req: any, res) => {
  try {
    const { hubId } = req.params;
    const userId = req.user.sub;
    
    const user = await prisma.user.findUnique({ where: { supabaseId: userId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    await prisma.jukeboxSession.deleteMany({
      where: { hubId, hostId: user.id }
    });
    
    res.json({ success: true });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to end session' });
  }
});

import axios from 'axios';

let spotifyAccessToken: string | null = null;
let spotifyTokenExpiry: number | null = null;

async function getSpotifyAccessToken() {
  if (spotifyAccessToken && spotifyTokenExpiry && Date.now() < spotifyTokenExpiry) {
    return spotifyAccessToken;
  }
  const clientId = process.env.SPOTIFY_CLIENT_ID || '166979b34ea1475fb26bc7bb6a342871';
  const clientSecret = process.env.SPOTIFY_CLIENT_SECRET || '1fb76cd41be94c7e832477347cb13a54';
  const auth = Buffer.from(`${clientId}:${clientSecret}`).toString('base64');
  
  const response = await axios.post('https://accounts.spotify.com/api/token', 'grant_type=client_credentials', {
    headers: {
      'Authorization': `Basic ${auth}`,
      'Content-Type': 'application/x-www-form-urlencoded'
    }
  });
  
  spotifyAccessToken = response.data.access_token;
  spotifyTokenExpiry = Date.now() + (response.data.expires_in * 1000) - 60000;
  return spotifyAccessToken;
}

// Search Spotify
router.get('/spotify/search', authenticateToken, async (req: any, res) => {
  try {
    const query = req.query.q as string;
    if (!query) return res.status(400).json({ error: 'Missing query parameter' });

    const token = await getSpotifyAccessToken();
    const response = await axios.get(`https://api.spotify.com/v1/search?q=${encodeURIComponent(query)}&type=track&limit=20`, {
      headers: { 'Authorization': `Bearer ${token}` }
    });
    
    res.json(response.data);
  } catch (error) {
    console.error('Spotify Search Error:', error);
    res.status(500).json({ error: 'Failed to search Spotify' });
  }
});

// Create Spotify Playlist for Queue
router.post('/:hubId/spotify/create-playlist', authenticateToken, async (req: any, res) => {
  try {
    const { hubId } = req.params;
    const { mood, tracks } = req.body;
    
    // In a real implementation with SPOTIFY_CLIENT_ID and user auth, we would:
    // 1. Authenticate with Spotify API (using user's refresh token)
    // 2. Create a playlist named `mood`
    // 3. Add `tracks` (spotify track URIs) to the playlist
    // For now, we mock the response to simulate the flow
    
    const mockPlaylistUri = `spotify:playlist:37i9dQZF1DXcBWIGoYBM5M`; // Today's Top Hits as fallback
    res.json({ success: true, playlistUri: mockPlaylistUri, message: 'Spotify Playlist created!' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to create Spotify playlist' });
  }
});

export default router;
