import crypto from 'node:crypto';
import express from 'express';
import {
  optionalString,
  requireAmount,
  requireDate,
  requireString,
  requireType,
} from '../validate.js';

/** Shapes a transaction row for the client, matching the Dart model. */
function shape(row) {
  return {
    id: row.id,
    amount: row.amount,
    category: row.category,
    type: row.type,
    note: row.note,
    date: row.date,
  };
}

export function transactionRoutes() {
  const router = express.Router();

  router.get('/', (req, res) => {
    const rows = req.db
      .prepare(
        `SELECT id, amount, category, type, note, date
           FROM transactions
          WHERE user_id = ?
          ORDER BY date DESC, created_at DESC`,
      )
      .all(req.user.id);
    res.json(rows.map(shape));
  });

  router.post('/', (req, res) => {
    const amount = requireAmount(req.body?.amount);
    const type = requireType(req.body?.type);
    const category = requireString(req.body?.category, 'category', { max: 60 });
    const note = optionalString(req.body?.note, 'note', { max: 200 });
    const date = requireDate(req.body?.date);

    // Honour a client-supplied id so the Flutter app can keep its own primary
    // keys and stay idempotent across retries.
    const id =
      typeof req.body?.id === 'string' && req.body.id.trim() !== ''
        ? req.body.id.trim().slice(0, 64)
        : crypto.randomUUID();

    const clash = req.db
      .prepare('SELECT id FROM transactions WHERE id = ? AND user_id = ?')
      .get(id, req.user.id);
    if (clash) {
      return res.status(409).json({ error: 'A transaction with that id exists' });
    }

    req.db
      .prepare(
        `INSERT INTO transactions (id, user_id, amount, category, type, note, date)
         VALUES (?, ?, ?, ?, ?, ?, ?)`,
      )
      .run(id, req.user.id, amount, category, type, note, date);

    const row = req.db
      .prepare('SELECT * FROM transactions WHERE id = ?')
      .get(id);
    res.status(201).json(shape(row));
  });

  router.put('/:id', (req, res) => {
    const amount = requireAmount(req.body?.amount);
    const type = requireType(req.body?.type);
    const category = requireString(req.body?.category, 'category', { max: 60 });
    const note = optionalString(req.body?.note, 'note', { max: 200 });
    const date = requireDate(req.body?.date);

    // The WHERE clause includes user_id, so another account's id cannot be
    // edited even if the id is guessed.
    const info = req.db
      .prepare(
        `UPDATE transactions
            SET amount = ?, category = ?, type = ?, note = ?, date = ?
          WHERE id = ? AND user_id = ?`,
      )
      .run(amount, category, type, note, date, req.params.id, req.user.id);

    if (info.changes === 0) {
      return res.status(404).json({ error: 'Transaction not found' });
    }

    const row = req.db
      .prepare('SELECT * FROM transactions WHERE id = ?')
      .get(req.params.id);
    res.json(shape(row));
  });

  router.delete('/:id', (req, res) => {
    const info = req.db
      .prepare('DELETE FROM transactions WHERE id = ? AND user_id = ?')
      .run(req.params.id, req.user.id);

    if (info.changes === 0) {
      return res.status(404).json({ error: 'Transaction not found' });
    }
    res.json({ ok: true });
  });

  return router;
}