import { Router } from 'express';
import axios from 'axios';
import { authenticateToken } from '../middlewares/auth';

const router = Router();
const AI_LAYER_URL = process.env.AI_LAYER_URL || 'http://127.0.0.1:8000';

router.post('/summarise', authenticateToken, async (req, res) => {
  try {
    const { text } = req.body;
    const response = await axios.post(`${AI_LAYER_URL}/summarise`, { text });
    res.json(response.data);
  } catch (error) {
    console.error('AI Summarise Error:', error);
    res.status(500).json({ error: 'Failed to generate summary' });
  }
});

router.post('/plan-event', authenticateToken, async (req, res) => {
  try {
    const { event_type, group_size, location, budget } = req.body;
    const response = await axios.post(`${AI_LAYER_URL}/plan-event`, {
      event_type, group_size, location, budget
    });
    res.json(response.data);
  } catch (error) {
    console.error('AI Plan Error:', error);
    res.status(500).json({ error: 'Failed to generate plan' });
  }
});

router.post('/optimize-sport', authenticateToken, async (req, res) => {
  try {
    const { sport_type, date, lat, lng } = req.body;
    const response = await axios.post(`${AI_LAYER_URL}/optimize-sport`, {
      sport_type, date, lat, lng
    });
    res.json(response.data);
  } catch (error) {
    console.error('AI Optimize Error:', error);
    res.status(500).json({ error: 'Failed to optimize sport' });
  }
});

export default router;
