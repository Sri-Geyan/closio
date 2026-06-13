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

export default router;
