import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticateToken } from '../middlewares/auth';
import axios from 'axios';
import { discordService } from '../services/discordService';

const router = Router();
const prisma = new PrismaClient();

// Connect a gaming account manually (fallback)
router.post('/connect/:platform', authenticateToken, async (req, res) => {
  const { platform } = req.params;
  const supabaseId = req.user.sub;
  const { username } = req.body; // e.g., gamer tag provided

  const validPlatforms = ['steam', 'discord', 'xbox', 'psn', 'epic', 'riot'];
  if (!validPlatforms.includes(platform)) {
    return res.status(400).json({ error: 'Invalid platform' });
  }

  try {
    const updateData: any = {};
    const fieldMap: Record<string, string> = {
      steam: 'gamingSteam',
      discord: 'gamingDiscord',
      xbox: 'gamingXbox',
      psn: 'gamingPsn',
      epic: 'gamingEpic',
      riot: 'gamingRiot'
    };
    
    updateData[fieldMap[platform]] = username;

    const user = await prisma.user.update({
      where: { supabaseId },
      data: updateData
    });

    res.json({ success: true, user });
  } catch (error) {
    console.error(`Error connecting ${platform}:`, error);
    res.status(500).json({ error: 'Failed to connect gaming account' });
  }
});

// --- Discord OAuth ---

router.get('/discord/auth', (req, res) => {
  const { userId } = req.query; // the supabaseId
  if (!userId) return res.status(400).send('Missing userId');
  
  const clientId = process.env.DISCORD_CLIENT_ID;
  const redirectUri = encodeURIComponent(process.env.DISCORD_REDIRECT_URI || 'http://localhost:3000/gaming/discord/callback');
  const state = encodeURIComponent(userId as string);
  
  const authUrl = `https://discord.com/api/oauth2/authorize?client_id=${clientId}&redirect_uri=${redirectUri}&response_type=code&scope=identify&state=${state}`;
  res.redirect(authUrl);
});

router.get('/discord/callback', async (req, res) => {
  const { code, state } = req.query;
  
  if (!code || !state) {
    return res.status(400).send('Missing code or state');
  }

  const clientId = process.env.DISCORD_CLIENT_ID!;
  const clientSecret = process.env.DISCORD_CLIENT_SECRET!;
  const redirectUri = process.env.DISCORD_REDIRECT_URI || 'http://localhost:3000/gaming/discord/callback';

  try {
    const params = new URLSearchParams({
      client_id: clientId,
      client_secret: clientSecret,
      grant_type: 'authorization_code',
      code: code as string,
      redirect_uri: redirectUri
    });

    const tokenResponse = await axios.post('https://discord.com/api/oauth2/token', params.toString(), {
      headers: { 'Content-Type': 'application/x-www-form-urlencoded' }
    });

    const accessToken = tokenResponse.data.access_token;

    const userResponse = await axios.get('https://discord.com/api/users/@me', {
      headers: { Authorization: `Bearer ${accessToken}` }
    });

    const discordId = userResponse.data.id;
    const supabaseId = decodeURIComponent(state as string);

    await prisma.user.update({
      where: { supabaseId },
      data: { gamingDiscord: discordId }
    });

    res.send(`
      <html>
        <body style="background: #121212; color: #fff; font-family: sans-serif; display: flex; align-items: center; justify-content: center; height: 100vh;">
          <div style="text-align: center;">
            <h2>Discord Connected!</h2>
            <p>You can now close this browser and return to the Closio app.</p>
          </div>
        </body>
      </html>
    `);

  } catch (err: any) {
    console.error('Discord OAuth Error:', err.response?.data || err.message);
    res.status(500).send('Failed to connect Discord');
  }
});

// Update privacy controls
router.put('/privacy', authenticateToken, async (req, res) => {
  const supabaseId = req.user.sub;
  const { gamingPrivacy, gamingAppearOffline } = req.body;

  try {
    const user = await prisma.user.update({
      where: { supabaseId },
      data: {
        gamingPrivacy: gamingPrivacy !== undefined ? gamingPrivacy : undefined,
        gamingAppearOffline: gamingAppearOffline !== undefined ? gamingAppearOffline : undefined,
      }
    });
    res.json({ success: true, user });
  } catch (error) {
    console.error('Error updating privacy:', error);
    res.status(500).json({ error: 'Failed to update gaming privacy' });
  }
});

// Get user's gaming stats/status
router.get('/status/:userId', authenticateToken, async (req, res) => {
  const { userId } = req.params;
  
  try {
    const user = await prisma.user.findUnique({
      where: { id: userId }
    });

    if (!user) return res.status(404).json({ error: 'User not found' });

    // Enforce privacy
    if (user.gamingPrivacy === 'NOBODY') {
      return res.json({ status: 'hidden' });
    }
    // (If HUBS, we would check if they share a hub. For MVP, we skip complex hub intersection)
    
    if (user.gamingAppearOffline) {
      return res.json({ status: 'offline' });
    }

    // Return actual presence and stats based on connected accounts
    const stats: any = {};
    let presence = 'Online';

    if (user.gamingSteam) {
      stats.steam = { username: user.gamingSteam };
      if (presence === 'Online') presence = `Online on Steam`;
    }
    if (user.gamingDiscord) {
      const dPresence = discordService.getUserPresence(user.gamingDiscord);
      if (dPresence) {
        stats.discord = {
          username: dPresence.username,
          avatarUrl: dPresence.avatarUrl,
          globalName: dPresence.globalName,
        };
        if (dPresence.gameName) {
          presence = `Playing ${dPresence.gameName} on Discord`;
        } else {
          const statusMap: any = { online: 'Online', idle: 'Idle', dnd: 'Do Not Disturb', offline: 'Offline' };
          const s = statusMap[dPresence.status] || 'Online';
          presence = `${s} on Discord as ${dPresence.globalName || dPresence.username}`;
        }
      } else {
        // Fallback if bot can't see them
        presence = `Connected to Discord`;
      }
    }
    if (user.gamingRiot) {
      stats.riot = { username: user.gamingRiot };
      if (presence === 'Online') presence = `Online on Riot Games`;
    }
    if (user.gamingPsn) {
      stats.psn = { username: user.gamingPsn };
      if (presence === 'Online') presence = `Online on PlayStation Network`;
    }
    if (user.gamingXbox) {
      stats.xbox = { username: user.gamingXbox };
      if (presence === 'Online') presence = `Online on Xbox Live`;
    }

    res.json({
      presence,
      stats
    });

  } catch (error) {
    console.error('Error fetching gaming status:', error);
    res.status(500).json({ error: 'Failed to fetch gaming status' });
  }
});

export default router;
