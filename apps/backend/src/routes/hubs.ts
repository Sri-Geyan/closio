import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticateToken } from '../middlewares/auth';

const router = Router();
const prisma = new PrismaClient();

// Get all hubs the user belongs to
router.get('/', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user!.sub;
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const memberships = await prisma.hubMember.findMany({
      where: { userId: user.id },
      include: { hub: true }
    });
    
    res.json(memberships.map(m => m.hub));
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch hubs' });
  }
});

// Create a new hub
router.post('/', authenticateToken, async (req, res) => {
  try {
    const supabaseId = req.user!.sub;
    const { name, avatarUrl } = req.body;

    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const hub = await prisma.hub.create({
      data: { name, avatarUrl }
    });

    // Add creator to hub as Admin
    await prisma.hubMember.create({
      data: { hubId: hub.id, userId: user.id, role: 'Admin' }
    });

    res.json(hub);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create hub' });
  }
});

// Get hub members
router.get('/:id/members', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const members = await prisma.hubMember.findMany({
      where: { hubId: id },
      include: { user: true }
    });
    // Return user details along with their role in the hub
    res.json(members.map(m => ({ ...m.user, role: m.role })));
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch hub members' });
  }
});

// Add member to hub
router.post('/:id/members', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const { username } = req.body;
    
    // Find user to add
    const userToAdd = await prisma.user.findUnique({ where: { username } });
    if (!userToAdd) return res.status(404).json({ error: 'User not found' });

    // Ensure requestor is admin (optional safety check, we'll keep it simple for now)
    const supabaseId = req.user!.sub;
    const requestor = await prisma.user.findUnique({ where: { supabaseId } });
    if (!requestor) return res.status(401).json({ error: 'Unauthorized' });

    const requestorMember = await prisma.hubMember.findUnique({
      where: { hubId_userId: { hubId: id, userId: requestor.id } }
    });

    if (!requestorMember || requestorMember.role !== 'Admin') {
      return res.status(403).json({ error: 'Only Admins can add members' });
    }

    const newMember = await prisma.hubMember.create({
      data: { hubId: id, userId: userToAdd.id, role: 'Member' },
      include: { user: true }
    });

    res.json({ ...newMember.user, role: newMember.role });
  } catch (error) {
    res.status(500).json({ error: 'Failed to add member' });
  }
});

// Leave a hub
router.delete('/:id/members', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const supabaseId = req.user!.sub;

    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    await prisma.hubMember.delete({
      where: {
        hubId_userId: {
          hubId: id,
          userId: user.id,
        }
      }
    });
    
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to leave hub' });
  }
});

// Get hub messages
router.get('/:id/messages', authenticateToken, async (req, res) => {
  try {
    const { id } = req.params;
    const messages = await prisma.message.findMany({
      where: { hubId: id },
      orderBy: { createdAt: 'asc' },
      include: { sender: true }
    });
    res.json(messages);
  } catch (error) {
    res.status(500).json({ error: 'Failed to fetch messages' });
  }
});

export default router;
