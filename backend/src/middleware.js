import { verifyToken } from './auth.js';

/**
 * Requires a valid `Authorization: Bearer <token>` header.
 *
 * Attaches the authenticated row as `req.user`. Every data query is scoped by
 * `req.user.id`, so one account can never read or write another's records.
 */
export function requireAuth(jwtSecret) {
  return function authMiddleware(req, res, next) {
    const header = req.get('authorization') || '';
    const [scheme, token] = header.split(' ');

    if (scheme !== 'Bearer' || !token) {
      return res.status(401).json({ error: 'Missing bearer token' });
    }

    let claims;
    try {
      claims = verifyToken(token, jwtSecret);
    } catch (err) {
      const expired = err.name === 'TokenExpiredError';
      return res.status(401).json({
        error: expired ? 'Token expired' : 'Invalid token',
      });
    }

    const row = req.db
      .prepare('SELECT id, name, email, phone, address FROM users WHERE id = ?')
      .get(Number(claims.sub));

    // The token is well formed but the account is gone.
    if (!row) {
      return res.status(401).json({ error: 'Account no longer exists' });
    }

    req.user = row;
    next();
  };
}