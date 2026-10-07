import express from 'express';
import { publicUser } from '../auth.js';
import { optionalString, requireEmail, requireString } from '../validate.js';

export function profileRoutes() {
  const router = express.Router();

  router.get('/', (req, res) => {
    res.json(publicUser(req.user));
  });

  router.put('/', (req, res) => {
    const name = requireString(req.body?.name, 'name', { max: 120 });
    const email = requireEmail(req.body?.email ?? req.user.email);
    const phone = optionalString(req.body?.phone, 'phone', { max: 40 });
    const address = optionalString(req.body?.address, 'address', { max: 300 });

    const clash = req.db
      .prepare('SELECT id FROM users WHERE email = ? AND id != ?')
      .get(email, req.user.id);
    if (clash) {
      return res.status(409).json({ error: 'That email is already registered' });
    }

    req.db
      .prepare(
        `UPDATE users SET name = ?, email = ?, phone = ?, address = ? WHERE id = ?`,
      )
      .run(name, email, phone, address, req.user.id);

    const row = req.db.prepare('SELECT * FROM users WHERE id = ?').get(req.user.id);
    res.json(publicUser(row));
  });

  return router;
}