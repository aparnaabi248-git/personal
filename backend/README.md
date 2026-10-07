# Personal Finance API

REST backend for the Personal Finance Tracker Flutter app. Node + Express +
SQLite, with JWT auth. Built so the Flutter client can replace its local-only
storage with a real server.

> The Flutter app in this repo is still **local-first** — it talks to
> `SharedPreferences`, not to this API. See "Wiring the app up" below.

## Quick start

```bash
cd backend
npm install

# Generate a secret and put it in .env
node -e "console.log(require('crypto').randomBytes(32).toString('hex'))"
copy .env.example .env      # then paste the secret into JWT_SECRET

npm start                   # http://localhost:3000
npm test                    # 31 tests, no external services needed
```

Check it is alive:

```bash
curl http://localhost:3000/health     # {"ok":true}
```

## Configuration

| Variable        | Required | Default              | Purpose                                     |
| --------------- | -------- | -------------------- | ------------------------------------------- |
| `JWT_SECRET`    | yes      | —                    | Signs login tokens. Minimum 16 chars.       |
| `PORT`          | no       | `3000`               | Listen port. Platforms inject their own.    |
| `DATABASE_FILE` | no       | `./data/finance.db`  | SQLite path. Put it on a mounted volume.    |
| `NODE_ENV`      | no       | —                    | Set to `production` on deploys.             |

The process **refuses to start** without a valid `JWT_SECRET` rather than
falling back to a guessable default.

## API

All `/api/*` data routes need `Authorization: Bearer <token>`. Tokens last 7
days.

| Method   | Path                     | Body / query                       | Returns                    |
| -------- | ------------------------ | ---------------------------------- | -------------------------- |
| `GET`    | `/health`                | —                                  | `{ ok: true }`             |
| `POST`   | `/api/auth/register`     | `name, email, phone, password`     | `{ token, user }` `201`    |
| `POST`   | `/api/auth/login`        | `email, password`                  | `{ token, user }`          |
| `GET`    | `/api/profile`           | —                                  | `user`                     |
| `PUT`    | `/api/profile`           | `name, email, phone, address`      | `user`                     |
| `GET`    | `/api/transactions`      | —                                  | `transaction[]`            |
| `POST`   | `/api/transactions`      | `amount, category, type, note, date, id?` | `transaction` `201` |
| `PUT`    | `/api/transactions/:id`  | `amount, category, type, note, date` | `transaction`             |
| `DELETE` | `/api/transactions/:id`  | —                                  | `{ ok: true }`             |
| `GET`    | `/api/budget`            | `?month=YYYY-MM`                   | `{ month, budget }`        |
| `PUT`    | `/api/budget`            | `budget, month?`                   | `{ month, budget }`        |
| `GET`    | `/api/report`            | `?month=YYYY-MM`                   | totals, breakdown, trend   |

`type` must be exactly `"Income"` or `"Expense"`. `month` defaults to the
current month. Every response that returns a user omits `password_hash`.

### Legacy aliases

The singular top-level paths the app's original `ApiService` expected are still
served, so an older client keeps working: `POST /register`, `POST /login`,
`GET|POST /transaction(s)`, `PUT|DELETE /transaction/:id`, `GET|PUT /budget`,
`GET /report`, `GET|PUT /profile`.

### Errors

```json
{ "error": "Validation failed", "fields": ["amount must be greater than zero"] }
```

`400` validation · `401` missing/invalid/expired token · `404` not found or not
yours · `409` duplicate email or id · `500` unexpected.

## Security notes

- Passwords are bcrypt-hashed (10 rounds). Never logged, never returned.
- Login returns the same message for an unknown email and a wrong password, so
  it does not reveal which addresses are registered.
- Every query is scoped by the authenticated `user_id` — including updates and
  deletes — so one account cannot touch another's rows. This is covered by
  tests.
- All SQL uses prepared statements, so input cannot break out of a query.
- Amounts are rounded to two decimals on write to stop float drift. Money is
  stored as SQLite `REAL` to match the Dart client's `double`; a system handling
  real payments should switch to integer minor units.

## ⚠️ Persistence on Render / Railway / Fly

These platforms give you an **ephemeral filesystem** unless you attach a
volume. With no volume, the SQLite file is wiped on every deploy and every
restart — the API will look fine and silently lose all data.

- **Render** — `render.yaml` already requests a 1 GB disk at `/data` (paid).
- **Fly.io** — run `fly volumes create finance_data --size 1` before deploying.
- **Railway** — attach a volume at `/data`.

If you would rather not pay for a volume, switch to a managed Postgres and set
`DATABASE_URL`; that requires replacing `better-sqlite3` usage in `src/db.js`
and the queries.

## Deploying

You need to be logged in to the platform; no CLI is installed on this machine,
so these are for you to run.

### Render

```bash
git push                       # push the backend/ folder to your repo
# In the Render dashboard: New > Blueprint, point at the repo.
# render.yaml sets DATABASE_FILE, a generated JWT_SECRET and a 1 GB disk.
```

### Fly.io

```bash
fly launch --no-deploy --copy-config
fly volumes create finance_data --size 1
fly secrets set JWT_SECRET=$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")
fly deploy
fly status                     # note the hostname
```

### Docker anywhere

```bash
docker build -t pft-api .
docker run -p 3000:3000 \
  -e JWT_SECRET="$(node -e "console.log(require('crypto').randomBytes(32).toString('hex'))")" \
  -e DATABASE_FILE=/data/finance.db \
  -v pft-data:/data \
  pft-api
```

> The Dockerfile was written but **not build-verified** — the Docker daemon was
> not running on this machine. The app itself is verified: 31 tests pass and the
> server was smoke-tested over real HTTP.

## Wiring the app up

Not done, and it is not a small change. The Flutter app currently persists to
`SharedPreferences` and treats the device as the source of truth, so pointing it
at this API means:

1. Add `http` back to `pubspec.yaml`.
2. Recreate an API client (the old `ApiService`/`AuthService` were removed as
   dead code) with a configurable base URL via `--dart-define=API_URL=...`.
3. Store the JWT and re-attach it on launch instead of the `isLoggedIn` bool.
4. Decide what happens offline, and whether local `SharedPreferences` becomes a
   cache or disappears entirely.

Say the word and I will do it as a separate change.

## Layout

```
src/
  server.js        entrypoint: config, database, listen
  app.js           Express app, routing, error handling (testable, no listen)
  db.js            schema + connection
  auth.js          bcrypt hashing, JWT signing, public user shape
  middleware.js    requireAuth — attaches req.user
  validate.js      input validators, throws ValidationError with all fields
  routes/
    auth.js  transactions.js  budget.js  profile.js  report.js
test/
  api.test.js      31 tests over a real HTTP server on an in-memory database
```