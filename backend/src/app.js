import cors from 'cors';
import express from 'express';
import { requireAuth } from './middleware.js';
import { authRoutes, loginHandler, registerHandler } from './routes/auth.js';
import { budgetRoutes } from './routes/budget.js';
import { profileRoutes } from './routes/profile.js';
import { reportRoutes } from './routes/report.js';
import { transactionRoutes } from './routes/transactions.js';
import { ValidationError } from './validate.js';

/**
 * Builds the Express app.
 *
 * Kept separate from the server so tests can drive it without binding a port.
 *
 * @param {{ db: import('better-sqlite3').Database, jwtSecret: string }} deps
 */
export function createApp({ db, jwtSecret }) {
  const app = express();

  app.set('trust proxy', 1);
  // The Flutter web client is served from a different origin than the API.
  app.use(cors());
  app.use(express.json({ limit: '100kb' }));

  // Every request handler gets the shared database handle.
  app.use((req, _res, next) => {
    req.db = db;
    next();
  });

  app.get('/health', (_req, res) => {
    res.json({ ok: true });
  });

  const auth = requireAuth(jwtSecret);

  app.use('/api/auth', authRoutes({ jwtSecret }));
  app.use('/api/transactions', auth, transactionRoutes());
  app.use('/api/budget', auth, budgetRoutes());
  app.use('/api/profile', auth, profileRoutes());
  app.use('/api/report', auth, reportRoutes());

  // Singular aliases matching the app's original ApiService contract, so an
  // older client keeps working: /transaction, /profile, /budget, /report.
  app.use('/transaction', auth, transactionRoutes());
  app.use('/transactions', auth, transactionRoutes());
  app.use('/profile', auth, profileRoutes());
  app.use('/budget', auth, budgetRoutes());
  app.use('/report', auth, reportRoutes());
  app.post('/register', registerHandler(jwtSecret));
  app.post('/login', loginHandler(jwtSecret));

  app.use((req, res) => {
    res.status(404).json({ error: `No route for ${req.method} ${req.path}` });
  });

  // eslint-disable-next-line no-unused-vars -- Express needs the 4-arg shape.
  app.use((err, _req, res, _next) => {
    if (err instanceof ValidationError) {
      return res.status(400).json({ error: 'Validation failed', fields: err.fields });
    }
    if (err?.type === 'entity.parse.failed') {
      return res.status(400).json({ error: 'Body is not valid JSON' });
    }
    console.error(err);
    res.status(500).json({ error: 'Internal server error' });
  });

  return app;
}