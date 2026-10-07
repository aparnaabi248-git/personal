import assert from 'node:assert/strict';
import { after, before, describe, it } from 'node:test';
import { createApp } from '../src/app.js';
import { openDatabase } from '../src/db.js';

const JWT_SECRET = 'test-secret-at-least-16-chars';

/** Boots the app on an ephemeral port and returns a fetch helper. */
async function startServer() {
  const db = openDatabase(':memory:');
  const app = createApp({ db, jwtSecret: JWT_SECRET });

  const server = await new Promise((resolve) => {
    const s = app.listen(0, () => resolve(s));
  });

  const base = `http://127.0.0.1:${server.address().port}`;

  async function call(method, url, { body, token } = {}) {
    const res = await fetch(`${base}${url}`, {
      method,
      headers: {
        ...(body ? { 'Content-Type': 'application/json' } : {}),
        ...(token ? { Authorization: `Bearer ${token}` } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    const text = await res.text();
    return {
      status: res.status,
      body: text ? JSON.parse(text) : null,
    };
  }

  return { db, server, call, close: () => new Promise((r) => server.close(r)) };
}

let api;
let asha;
let rahul;

before(async () => {
  api = await startServer();

  const a = await api.call('POST', '/api/auth/register', {
    body: {
      name: 'Asha',
      email: 'asha@example.com',
      phone: '1234567890',
      password: 'password123',
    },
  });
  asha = a.body;

  const r = await api.call('POST', '/api/auth/register', {
    body: {
      name: 'Rahul',
      email: 'rahul@example.com',
      phone: '9999999999',
      password: 'password123',
    },
  });
  rahul = r.body;
});

after(async () => {
  api.db.close();
  await api.close();
});

describe('health', () => {
  it('reports ok without a token', async () => {
    const res = await api.call('GET', '/health');
    assert.equal(res.status, 200);
    assert.equal(res.body.ok, true);
  });
});

describe('registration', () => {
  it('creates an account and returns a token', async () => {
    assert.ok(asha.token);
    assert.equal(asha.user.email, 'asha@example.com');
    assert.equal(asha.user.id, '1');
  });

  it('never leaks the password hash', async () => {
    assert.equal(asha.user.password_hash, undefined);
    assert.equal(asha.user.passwordHash, undefined);
  });

  it('rejects a duplicate email', async () => {
    const res = await api.call('POST', '/api/auth/register', {
      body: {
        name: 'Someone Else',
        email: 'asha@example.com',
        password: 'password123',
      },
    });
    assert.equal(res.status, 409);
  });

  it('rejects a short password', async () => {
    const res = await api.call('POST', '/api/auth/register', {
      body: { name: 'X', email: 'x@example.com', password: '123' },
    });
    assert.equal(res.status, 400);
    assert.match(res.body.fields[0], /at least 6/);
  });

  it('rejects a malformed email', async () => {
    const res = await api.call('POST', '/api/auth/register', {
      body: { name: 'X', email: 'not-an-email', password: 'password123' },
    });
    assert.equal(res.status, 400);
  });
});

describe('login', () => {
  it('accepts the right password', async () => {
    const res = await api.call('POST', '/api/auth/login', {
      body: { email: 'asha@example.com', password: 'password123' },
    });
    assert.equal(res.status, 200);
    assert.ok(res.body.token);
  });

  it('is case-insensitive on the email', async () => {
    const res = await api.call('POST', '/api/auth/login', {
      body: { email: 'ASHA@example.com', password: 'password123' },
    });
    assert.equal(res.status, 200);
  });

  it('rejects a wrong password', async () => {
    const res = await api.call('POST', '/api/auth/login', {
      body: { email: 'asha@example.com', password: 'wrongpassword' },
    });
    assert.equal(res.status, 401);
  });

  it('gives the same message for an unknown account', async () => {
    const unknown = await api.call('POST', '/api/auth/login', {
      body: { email: 'nobody@example.com', password: 'password123' },
    });
    const wrong = await api.call('POST', '/api/auth/login', {
      body: { email: 'asha@example.com', password: 'wrongpassword' },
    });
    assert.equal(unknown.status, wrong.status);
    assert.equal(unknown.body.error, wrong.body.error);
  });
});

describe('authorization', () => {
  it('refuses a request with no token', async () => {
    const res = await api.call('GET', '/api/transactions');
    assert.equal(res.status, 401);
  });

  it('refuses a malformed token', async () => {
    const res = await api.call('GET', '/api/transactions', { token: 'nonsense' });
    assert.equal(res.status, 401);
  });
});

describe('transactions', () => {
  it('creates, lists, edits and deletes', async () => {
    const created = await api.call('POST', '/api/transactions', {
      token: asha.token,
      body: {
        amount: 250.5,
        category: 'Food',
        type: 'Expense',
        note: 'Team lunch',
        date: '2026-10-05T00:00:00.000Z',
      },
    });
    assert.equal(created.status, 201);
    assert.equal(created.body.amount, 250.5);
    assert.equal(created.body.date, '2026-10-05');

    const list = await api.call('GET', '/api/transactions', { token: asha.token });
    assert.equal(list.body.length, 1);

    const edited = await api.call(
      'PUT',
      `/api/transactions/${created.body.id}`,
      {
        token: asha.token,
        body: {
          amount: 300,
          category: 'Food',
          type: 'Expense',
          note: 'Team dinner',
          date: '2026-10-06T00:00:00.000Z',
        },
      },
    );
    assert.equal(edited.body.amount, 300);

    const removed = await api.call(
      'DELETE',
      `/api/transactions/${created.body.id}`,
      { token: asha.token },
    );
    assert.equal(removed.status, 200);

    const after = await api.call('GET', '/api/transactions', { token: asha.token });
    assert.equal(after.body.length, 0);
  });

  it('rejects a negative amount', async () => {
    const res = await api.call('POST', '/api/transactions', {
      token: asha.token,
      body: { amount: -50, category: 'Food', type: 'Expense' },
    });
    assert.equal(res.status, 400);
  });

  it('rejects a zero amount', async () => {
    const res = await api.call('POST', '/api/transactions', {
      token: asha.token,
      body: { amount: 0, category: 'Food', type: 'Expense' },
    });
    assert.equal(res.status, 400);
  });

  it('rejects an unknown type', async () => {
    const res = await api.call('POST', '/api/transactions', {
      token: asha.token,
      body: { amount: 10, category: 'Food', type: 'Transfer' },
    });
    assert.equal(res.status, 400);
  });

  it('rounds an amount to two decimals', async () => {
    const res = await api.call('POST', '/api/transactions', {
      token: asha.token,
      body: { amount: 10.567, category: 'Food', type: 'Expense' },
    });
    assert.equal(res.body.amount, 10.57);
  });

  it('honours a client-supplied id and refuses a duplicate', async () => {
    const body = {
      id: 'client-id-1',
      amount: 12,
      category: 'Food',
      type: 'Expense',
    };
    const first = await api.call('POST', '/api/transactions', {
      token: asha.token,
      body,
    });
    assert.equal(first.status, 201);

    const second = await api.call('POST', '/api/transactions', {
      token: asha.token,
      body,
    });
    assert.equal(second.status, 409);
  });

  it('keeps one account out of another account data', async () => {
    await api.call('POST', '/api/transactions', {
      token: asha.token,
      body: {
        id: 'asha-only',
        amount: 999,
        category: 'Secret',
        type: 'Expense',
      },
    });

    // Rahul cannot see it.
    const rahulList = await api.call('GET', '/api/transactions', {
      token: rahul.token,
    });
    assert.equal(rahulList.body.length, 0);

    // Nor edit it.
    const edit = await api.call('PUT', '/api/transactions/asha-only', {
      token: rahul.token,
      body: { amount: 1, category: 'Hack', type: 'Expense' },
    });
    assert.equal(edit.status, 404);

    // Nor delete it.
    const del = await api.call('DELETE', '/api/transactions/asha-only', {
      token: rahul.token,
    });
    assert.equal(del.status, 404);

    // Asha still has it.
    const ashaList = await api.call('GET', '/api/transactions', {
      token: asha.token,
    });
    assert.ok(ashaList.body.some((t) => t.id === 'asha-only'));
  });
});

describe('budget', () => {
  it('defaults to zero, then sets and replaces', async () => {
    const empty = await api.call('GET', '/api/budget', { token: asha.token });
    assert.equal(empty.body.budget, 0);

    const set = await api.call('PUT', '/api/budget', {
      token: asha.token,
      body: { budget: 50000 },
    });
    assert.equal(set.status, 200);
    assert.equal(set.body.budget, 50000);

    const update = await api.call('PUT', '/api/budget', {
      token: asha.token,
      body: { budget: 60000 },
    });
    assert.equal(update.body.budget, 60000);

    const read = await api.call('GET', '/api/budget', { token: asha.token });
    assert.equal(read.body.budget, 60000);
  });

  it('keeps budgets separate per account', async () => {
    const rahulBudget = await api.call('GET', '/api/budget', { token: rahul.token });
    assert.equal(rahulBudget.body.budget, 0);
  });

  it('scopes a budget to a month', async () => {
    await api.call('PUT', '/api/budget', {
      token: asha.token,
      body: { budget: 12345, month: '2025-01' },
    });

    const january = await api.call('GET', '/api/budget?month=2025-01', {
      token: asha.token,
    });
    assert.equal(january.body.budget, 12345);

    const other = await api.call('GET', '/api/budget?month=2025-02', {
      token: asha.token,
    });
    assert.equal(other.body.budget, 0);
  });

  it('rejects a malformed month', async () => {
    const res = await api.call('GET', '/api/budget?month=2025-13', {
      token: asha.token,
    });
    assert.equal(res.status, 400);
  });
});

describe('profile', () => {
  it('returns the signed-in user', async () => {
    const res = await api.call('GET', '/api/profile', { token: asha.token });
    assert.equal(res.body.email, 'asha@example.com');
    assert.equal(res.body.name, 'Asha');
  });

  it('updates the profile', async () => {
    const res = await api.call('PUT', '/api/profile', {
      token: asha.token,
      body: {
        name: 'Asha Rao',
        email: 'asha@example.com',
        phone: '5555555555',
        address: 'Pune',
      },
    });
    assert.equal(res.status, 200);
    assert.equal(res.body.name, 'Asha Rao');
    assert.equal(res.body.address, 'Pune');
  });

  it('refuses to take an email another account already uses', async () => {
    const res = await api.call('PUT', '/api/profile', {
      token: asha.token,
      body: {
        name: 'Asha Rao',
        email: 'rahul@example.com',
        phone: '',
        address: '',
      },
    });
    assert.equal(res.status, 409);
  });
});

describe('report', () => {
  it('totals, breaks down by category and builds a six-month trend', async () => {
    await api.call('POST', '/api/transactions', {
      token: rahul.token,
      body: { amount: 90000, category: 'Salary', type: 'Income', date: '2026-10-01' },
    });
    await api.call('POST', '/api/transactions', {
      token: rahul.token,
      body: { amount: 30000, category: 'Bills', type: 'Expense', date: '2026-10-02' },
    });
    await api.call('POST', '/api/transactions', {
      token: rahul.token,
      body: { amount: 20000, category: 'Food', type: 'Expense', date: '2026-10-03' },
    });
    await api.call('POST', '/api/transactions', {
      token: rahul.token,
      body: { amount: 10000, category: 'Salary', type: 'Income', date: '2026-09-01' },
    });

    const res = await api.call('GET', '/api/report?month=2026-10', {
      token: rahul.token,
    });

    assert.equal(res.status, 200);
    assert.equal(res.body.monthTotals.income, 90000);
    assert.equal(res.body.monthTotals.expense, 50000);
    assert.equal(res.body.expenseByCategory.Bills, 30000);
    assert.equal(res.body.expenseByCategory.Food, 20000);
    assert.equal(res.body.transactionCount, 4);

    assert.equal(res.body.trend.length, 6);
    assert.equal(res.body.trend.at(-1).month, '2026-10');
    assert.equal(res.body.trend.at(-1).income, 90000);
    assert.equal(res.body.trend.at(-2).income, 10000);
    assert.equal(res.body.trend[0].income, 0);
  });

  it('excludes another account transactions from the report', async () => {
    const res = await api.call('GET', '/api/report', { token: asha.token });

    // Rahul holds a 90000 Salary and a 30000 Bills expense; none of it may
    // appear in Asha's report.
    assert.equal(res.body.totals.income, 0);
    assert.equal(res.body.expenseByCategory.Bills, undefined);
    assert.equal(res.body.expenseByCategory.Food, 22.57); // 10.57 + 12
    assert.equal(res.body.expenseByCategory.Secret, 999);
    assert.equal(res.body.totals.expense, 1021.57);
  });
});

describe('legacy aliases', () => {
  it('serves the original ApiService paths', async () => {
    const list = await api.call('GET', '/transactions', { token: rahul.token });
    assert.equal(list.status, 200);
    assert.ok(Array.isArray(list.body));

    const created = await api.call('POST', '/transaction', {
      token: rahul.token,
      body: { amount: 5, category: 'Gift', type: 'Expense' },
    });
    assert.equal(created.status, 201);

    const report = await api.call('GET', '/report', { token: rahul.token });
    assert.equal(report.status, 200);
  });
});

describe('robustness', () => {
  it('returns 404 for an unknown route', async () => {
    const res = await api.call('GET', '/api/nope');
    assert.equal(res.status, 404);
  });

  it('returns 400 for malformed JSON', async () => {
    const res = await fetch(`http://127.0.0.1:${api.server.address().port}/api/auth/login`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: '{ not json',
    });
    assert.equal(res.status, 400);
  });
});