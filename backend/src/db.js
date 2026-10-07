import Database from 'better-sqlite3';
import fs from 'node:fs';
import path from 'node:path';

/**
 * SQLite persistence.
 *
 * A single file database keeps the service simple to run and deploy. On
 * Render / Railway / Fly that file must live on a mounted volume, otherwise
 * every deploy starts from an empty database — see README.
 */

const SCHEMA = `
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER PRIMARY KEY AUTOINCREMENT,
  name          TEXT    NOT NULL,
  email         TEXT    NOT NULL UNIQUE COLLATE NOCASE,
  phone         TEXT    NOT NULL DEFAULT '',
  address       TEXT    NOT NULL DEFAULT '',
  password_hash TEXT    NOT NULL,
  created_at    TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS transactions (
  id         TEXT    PRIMARY KEY,
  user_id    INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  amount     REAL    NOT NULL,
  category   TEXT    NOT NULL,
  type       TEXT    NOT NULL CHECK (type IN ('Income', 'Expense')),
  note       TEXT    NOT NULL DEFAULT '',
  date       TEXT    NOT NULL,
  created_at TEXT    NOT NULL DEFAULT (datetime('now'))
);

CREATE INDEX IF NOT EXISTS idx_tx_user_date
  ON transactions (user_id, date DESC);

CREATE TABLE IF NOT EXISTS budgets (
  user_id INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  month   TEXT    NOT NULL,
  amount  REAL    NOT NULL,
  PRIMARY KEY (user_id, month)
);
`;

/**
 * Opens (and migrates) the database.
 *
 * @param {string} file Path to the SQLite file, or ':memory:' for tests.
 * @returns {import('better-sqlite3').Database}
 */
export function openDatabase(file) {
  if (file !== ':memory:') {
    fs.mkdirSync(path.dirname(file), { recursive: true });
  }

  const db = new Database(file);
  db.pragma('journal_mode = WAL');
  db.pragma('foreign_keys = ON');
  db.exec(SCHEMA);
  return db;
}