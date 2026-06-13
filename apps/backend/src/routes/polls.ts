import { Router } from 'express';
import { PrismaClient } from '@prisma/client';
import { authenticateToken } from '../middlewares/auth';

const router = Router();
const prisma = new PrismaClient();

// Create a Poll
router.post('/', authenticateToken, async (req, res) => {
  try {
    const { messageId, question, type, options, expiryDate, isAnonymous } = req.body;
    
    // Check if message exists
    const message = await prisma.message.findUnique({ where: { id: messageId } });
    if (!message) return res.status(404).json({ error: 'Message not found' });

    const poll = await prisma.poll.create({
      data: {
        messageId,
        question,
        type,
        expiryDate,
        isAnonymous,
        options: {
          create: options.map((opt: any) => ({
            text: opt.text,
            dateValue: opt.dateValue ? new Date(opt.dateValue) : null
          }))
        }
      },
      include: { options: true, message: true }
    });

    const supabaseId = req.user!.sub;
    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (user) {
      import('../utils/notifications').then(({ sendHubNotification }) => {
        sendHubNotification(poll.message.hubId, user.id, 'New Poll Created!', `${user.username} created a poll: ${question}`);
      });
    }

    res.json(poll);
  } catch (error) {
    res.status(500).json({ error: 'Failed to create poll' });
  }
});

// Vote in a Poll
router.post('/:pollId/vote', authenticateToken, async (req, res) => {
  try {
    const { pollId } = req.params;
    const { optionIds } = req.body; // array of optionIds
    const supabaseId = req.user!.sub;

    const user = await prisma.user.findUnique({ where: { supabaseId } });
    if (!user) return res.status(404).json({ error: 'User not found' });

    const poll = await prisma.poll.findUnique({ where: { id: pollId }, include: { options: true } });
    if (!poll || poll.isClosed) return res.status(400).json({ error: 'Poll not found or closed' });

    // For SINGLE choice, remove previous votes
    if (poll.type === 'SINGLE') {
      const optionIdsForPoll = poll.options.map(o => o.id);
      await prisma.pollVote.deleteMany({
        where: {
          userId: user.id,
          optionId: { in: optionIdsForPoll }
        }
      });
    }

    // Add new votes
    const newVotes = [];
    for (const optionId of optionIds) {
      const vote = await prisma.pollVote.upsert({
        where: { optionId_userId: { optionId, userId: user.id } },
        update: {},
        create: { optionId, userId: user.id }
      });
      newVotes.push(vote);
    }

    res.json({ success: true, votes: newVotes });
  } catch (error) {
    res.status(500).json({ error: 'Failed to vote' });
  }
});

// Close a Poll manually
router.post('/:pollId/close', authenticateToken, async (req, res) => {
  try {
    const { pollId } = req.params;
    const poll = await prisma.poll.update({
      where: { id: pollId },
      data: { isClosed: true }
    });
    res.json(poll);
  } catch (error) {
    res.status(500).json({ error: 'Failed to close poll' });
  }
});

export default router;
