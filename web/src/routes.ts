import { Router } from 'express';

const router = Router();

// Healthy route
router.get('/', (req, res) => {
  res.send('OK');
});

export default router;
