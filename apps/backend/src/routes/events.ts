import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticateToken } from '../middlewares/auth';
import { DeepLinkOrchestrator } from '../services/deepLinkService';

const router = Router();
const prisma = new PrismaClient();

// Get upcoming events for user's hubs
router.get('/', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user!.sub;
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    // Find all hubs user is in
    const memberships = await prisma.hubMember.findMany({
      where: { userId: user.id }
    });
    const hubIds = memberships.map(m => m.hubId);

    const events = await prisma.event.findMany({
      where: { hubId: { in: hubIds } },
      orderBy: { date: 'asc' },
      include: {
        hub: true,
        attendances: {
          include: {
            user: {
              select: { username: true, avatarUrl: true }
            }
          }
        }
      }
    });
    res.json(events);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch events' });
  }
});

// Update RSVP status
router.post('/:id/rsvp', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { status } = req.body; // Going, Maybe, Can't go
    const supabaseId = req.user!.sub;

    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const attendance = await prisma.eventAttendance.upsert({
      where: {
        eventId_userId: {
          eventId: id,
          userId: user.id
        }
      },
      update: { status },
      create: {
        eventId: id,
        userId: user.id,
        status
      }
    });
    res.json(attendance);
  } catch (error) {
    res.status(500).json({ error: 'Failed to update RSVP' });
  }
});

// Create a new event
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { hubId, title, description, date, time, location, type, rsvpStatus, sportType, sportDetails, lobbyLink } = req.body;
    const supabaseId = req.user!.sub;

    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });
    
    // In V1, we just create the event. Analytics would hook here.
    const event = await prisma.event.create({
      data: {
        hubId,
        title,
        description,
        date,
        time,
        location,
        type, // Hangout, Food, Movie, Sport
        sportType,
        sportDetails,
        lobbyLink,
        attendances: {
          create: {
            userId: user.id,
            status: rsvpStatus || 'Going'
          }
        }
      }
    });

    import('../utils/notifications').then(({ sendHubNotification }) => {
      sendHubNotification(hubId, user.id, 'New Event Created!', `${user.username} just created: ${title}`);
    });

    res.json(event);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create event' });
  }
});

// Deep Link Orchestration Engine Endpoints
router.get('/:id/action-links', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const event = await prisma.event.findUnique({ where: { id } });
    if (!event) return res.status(404).json({ error: 'Event not found' });

    const links = await DeepLinkOrchestrator.getRankedLinks(event);
    res.json(links);
  } catch (error) {
    res.status(500).json({ error: 'Failed to generate action links' });
  }
});

router.post('/:id/action-links/:linkType/tap', authenticateToken, async (req, res) => {
  try {
    const { id, linkType } = req.params;
    const event = await prisma.event.findUnique({ where: { id } });
    if (!event) return res.status(404).json({ error: 'Event not found' });

    await DeepLinkOrchestrator.recordTap(event.hubId, linkType);
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to record tap' });
  }
});

export default router;
