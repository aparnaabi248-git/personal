import express from 'express';
import { optionalMonth, requireAmount } from '../validate.js';

export function budgetRoutes() {
  const router = express.Router();

  router.get('/', (req, res) => {
    const month = optionalMonth(req.query.month);
    const row = req.db
      .prepare('SELECT amount FROM budgets WHERE user_id = ? AND month = ?')
      .get(req.user.id, month);

    res.json({ month, budget: row ? row.amount : 0 });
  });

  // PUT rather than POST so setting the same month twice is an update, not a
  // duplicate row.
  router.put('/', (req, res) => {
    const month = optionalMonth(req.body?.month);
    const amount = requireAmount(req.body?.budget ?? req.body?.amount, 'budget');

    req.db
      .prepare(
        `INSERT INTO budgets (user_id, month, amount)
         VALUES (?, ?, ?)
         ON CONFLICT (user_id, month) DO UPDATE SET amount = excluded.amount`,
      )
      .run(req.user.id, month, amount);

    res.json({ month, budget: amount });
  });

  return router;
}