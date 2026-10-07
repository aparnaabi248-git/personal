import { createApp } from './app.js';
import { openDatabase } from './db.js';

/**
 * Process entrypoint: reads config, opens the database, starts listening.
 *
 * Configuration comes from the environment so the same image runs locally and
 * on Render / Railway / Fly without edits.
 */

const PORT = Number(process.env.PORT) || 3000;
const JWT_SECRET = process.env.JWT_SECRET;

// Refusing to start beats silently signing tokens with a guessable default.
if (!JWT_SECRET || JWT_SECRET.length < 16) {
  console.error(
    'JWT_SECRET must be set to a random string of at least 16 characters.\n' +
      'Generate one with:  node -e "console.log(require(\'crypto\').randomBytes(32).toString(\'hex\'))"',
  );
  process.exit(1);
}

const dbFile = process.env.DATABASE_FILE || './data/finance.db';
const db = openDatabase(dbFile);
const app = createApp({ db, jwtSecret: JWT_SECRET });

const server = app.listen(PORT, () => {
  console.log(`Personal Finance API listening on port ${PORT}`);
  console.log(`Database: ${dbFile}`);
});

// Finish in-flight requests before exiting so a redeploy does not cut a write.
for (const signal of ['SIGINT', 'SIGTERM']) {
  process.on(signal, () => {
    server.close(() => {
      db.close();
      process.exit(0);
    });
  });
}