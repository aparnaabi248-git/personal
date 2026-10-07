import express from 'express';
import { hashPassword, publicUser, signToken, verifyPassword } from '../auth.js';
import {
  requireEmail,
  requirePassword,
  requireString,
} from '../validate.js';

/**
 * Handlers are exported individually so they can also be mounted on the
 * legacy top-level paths (`/register`, `/login`) without reaching into
 * Express internals.
 */
export function registerHandler(jwtSecret) {
  return (req, res) => {
    const name = requireString(req.body?.name, 'name', { max: 120 });
    const email = requireEmail(req.body?.email);
    const phone = typeof req.body?.phone === 'string' ? req.body.phone.trim() : '';
    const password = requirePassword(req.body?.password);

    const existing = req.db.prepare('SELECT id FROM users WHERE email = ?').get(email);
    if (existing) {
      return res.status(409).json({ error: 'That email is already registered' });
    }

    const info = req.db
      .prepare(
        `INSERT INTO users (name, email, phone, address, password_hash)
         VALUES (?, ?, ?, '', ?)`,
      )
      .run(name, email, phone, hashPassword(password));

    const user = req.db.prepare('SELECT * FROM users WHERE id = ?').get(info.lastInsertRowid);

    res.status(201).json({ token: signToken(user, jwtSecret), user: publicUser(user) });
  };
}

export function loginHandler(jwtSecret) {
  return (req, res) => {
    const email = requireEmail(req.body?.email);
    const password = requirePassword(req.body?.password);

    const user = req.db.prepare('SELECT * FROM users WHERE email = ?').get(email);

    // Same message for unknown email and wrong password so the response does
    // not reveal which emails are registered.
    const ok = user && verifyPassword(password, user.password_hash);
    if (!ok) {
      return res.status(401).json({ error: 'Invalid email or password' });
    }

    res.json({ token: signToken(user, jwtSecret), user: publicUser(user) });
  };
}

export function authRoutes({ jwtSecret }) {
  const router = express.Router();
  router.post('/register', registerHandler(jwtSecret));
  router.post('/login', loginHandler(jwtSecret));
  return router;
}