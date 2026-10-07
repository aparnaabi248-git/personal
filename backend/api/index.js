import { createApp } from '../src/app.js';
import { openDatabase } from '../src/db.js';

const jwtSecret = process.env.JWT_SECRET;

if (!jwtSecret || jwtSecret.length < 16) {
  throw new Error('JWT_SECRET is missing or too short');
}

const dbFile = process.env.DATABASE_FILE || '/tmp/finance.db';
const db = openDatabase(dbFile);

const app = createApp({ db, jwtSecret });

export default app;
