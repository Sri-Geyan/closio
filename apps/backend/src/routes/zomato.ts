import { Router } from 'express';
import { authenticateToken } from '../middlewares/auth';
import { zomatoService } from '../services/zomatoService';

const router = Router();

router.use(authenticateToken);

router.post('/bind', async (req, res) => {
  try {
    const { phoneNumber } = req.body;
    const result = await zomatoService.bindNumber(req.user.sub, phoneNumber);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/verify', async (req, res) => {
  try {
    const { code, stateId } = req.body;
    const result = await zomatoService.verifyCode(req.user.sub, code, stateId);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/restaurants', async (req, res) => {
  try {
    const { keyword, lat, lng } = req.query;
    const result = await zomatoService.getRestaurants(
      req.user.sub,
      keyword as string,
      parseFloat(lat as string),
      parseFloat(lng as string)
    );
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.get('/restaurants/:resId/menu', async (req, res) => {
  try {
    const result = await zomatoService.getMenu(req.user.sub, parseInt(req.params.resId));
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/cart', async (req, res) => {
  try {
    const { resId, items, addressId, paymentType } = req.body;
    const result = await zomatoService.createCart(req.user.sub, resId, items, addressId, paymentType);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

router.post('/checkout', async (req, res) => {
  try {
    const { cartId } = req.body;
    const result = await zomatoService.checkoutCart(req.user.sub, cartId);
    res.json(result);
  } catch (error: any) {
    res.status(500).json({ error: error.message });
  }
});

export default router;
