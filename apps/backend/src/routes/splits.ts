import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticateToken } from '../middlewares/auth';

const router = Router();
const prisma = new PrismaClient();

// Create a split
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { eventId, totalAmount, type, participants } = req.body;
    // participants = [{ userId, amountOwed }]

    const split = await prisma.split.create({
      data: {
        eventId,
        totalAmount,
        type, // Equal, Custom
        participants: {
          create: participants.map((p: any) => ({
            userId: p.userId,
            amountOwed: p.amountOwed
          }))
        }
      },
      include: { participants: true, event: true }
    });

    const supabaseId = req.user!.sub;
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (user) {
      import('../utils/notifications').then(({ sendHubNotification }) => {
        sendHubNotification(split.event.hubId, user.id, 'New Split Added!', `${user.username} split $${totalAmount} for ${split.event.title}`);
      });
    }

    res.json(split);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create split' });
  }
});

// Get splits for a user
router.get('/', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user!.sub;
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const participations = await prisma.splitParticipant.findMany({
      where: { userId: user.id },
      include: {
        split: {
          include: { event: true }
        }
      }
    });

    res.json(participations);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch splits' });
  }
});

// Get all splits for a hub
router.get('/hub/:hubId', authenticateToken, async (req, res) => {
  try {
    const { hubId } = req.params;
    
    // Find all events in this hub
    const events = await prisma.event.findMany({
      where: { hubId }
    });
    const eventIds = events.map(e => e.id);

    // Find all splits for these events
    const splits = await prisma.split.findMany({
      where: { eventId: { in: eventIds } },
      include: {
        event: true,
        participants: {
          include: { user: true }
        }
      },
      orderBy: { createdAt: 'desc' }
    });

    res.json(splits);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch hub splits' });
  }
});

// Settle a split participant (toggle isPaid)
router.post('/:participantId/settle', authenticateToken, async (req, res) => {
  try {
    const { participantId } = req.params;
    const { isPaid } = req.body;

    const participant = await prisma.splitParticipant.update({
      where: { id: participantId },
      data: { isPaid },
      include: {
        user: true,
        split: {
          include: { event: true }
        }
      }
    });

    res.json(participant);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update settlement status' });
  }
});

export default router;
// Trigger comment
