import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticateToken } from '../middlewares/auth';

const router = Router();
const prisma = new PrismaClient();

// Get all active location shares for the hubs the current user is part of
router.get('/', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user.sub;
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Find all hubs user is a member of
    const memberships = await prisma.hubMember.findMany({
      where: { userId: user.id }
    });
    const hubIds = memberships.map(m => m.hubId);

    if (hubIds.length === 0) {
      return res.json([]);
    }

    // Find all active locations in those hubs
    const activeLocations = await prisma.locationShare.findMany({
      where: {
        hubId: { in: hubIds },
        expiresAt: { gt: new Date() }
      },
      include: {
        user: { select: { id: true, username: true, avatarUrl: true } }
      }
    });

    res.json(activeLocations);
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to fetch locations' });
  }
});

// Share location to all hubs the user is in
router.post('/share-all', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user.sub;
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const { latitude, longitude, durationMinutes = 60 } = req.body;
    const expiresAt = new Date(Date.now() + durationMinutes * 60000);

    // Get all hubs the user is part of
    const memberships = await prisma.hubMember.findMany({
      where: { userId: user.id }
    });

    for (const membership of memberships) {
      const existing = await prisma.locationShare.findFirst({
        where: { hubId: membership.hubId, userId: user.id }
      });

      if (existing) {
        await prisma.locationShare.update({
          where: { id: existing.id },
          data: { latitude, longitude, expiresAt }
        });
      } else {
        await prisma.locationShare.create({
          data: {
            hubId: membership.hubId,
            userId: user.id,
            latitude,
            longitude,
            expiresAt
          }
        });
      }
    }

    res.json({ success: true, message: 'Location shared to all hubs.' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to share location' });
  }
});

// Stop sharing location to all hubs
router.delete('/share-all', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user.sub;
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    await prisma.locationShare.deleteMany({
      where: { userId: user.id }
    });

    res.json({ success: true, message: 'Stopped sharing location.' });
  } catch (error) {
    console.error(error);
    res.status(500).json({ error: 'Failed to stop sharing location' });
  }
});

export default router;
