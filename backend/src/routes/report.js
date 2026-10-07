import express from 'express';
import { optionalMonth } from '../validate.js';

const MONTH_LABELS = [
  'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
  'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
];

export function reportRoutes() {
  const router = express.Router();

  router.get('/', (req, res) => {
    const month = optionalMonth(req.query.month);
    const userId = req.user.id;

    const all = req.db
      .prepare(
        `SELECT type, category, amount FROM transactions
          WHERE user_id = ?
          ORDER BY date DESC`,
      )
      .all(userId);

    const monthTotals = req.db
      .prepare(
        `SELECT
            COALESCE(SUM(CASE WHEN type = 'Income'  THEN amount END), 0) AS income,
            COALESCE(SUM(CASE WHEN type = 'Expense' THEN amount END), 0) AS expense
           FROM transactions
          WHERE user_id = ? AND substr(date, 1, 7) = ?`,
      )
      .get(userId, month);

    const round = (n) => Math.round(n * 100) / 100;

    // Breakdown by category, split by direction.
    const expenseByCategory = {};
    const incomeByCategory = {};
    let income = 0;
    let expense = 0;

    for (const row of all) {
      if (row.type === 'Income') {
        income += row.amount;
        incomeByCategory[row.category] =
          round((incomeByCategory[row.category] ?? 0) + row.amount);
      } else {
        expense += row.amount;
        expenseByCategory[row.category] =
          round((expenseByCategory[row.category] ?? 0) + row.amount);
      }
    }

    // Six-month trend, oldest first, ending with the requested month.
    const [year, monthNumber] = month.split('-').map(Number);
    const trend = [];
    const rowsByMonth = new Map(
      req.db
        .prepare(
          `SELECT substr(date, 1, 7) AS month,
                  COALESCE(SUM(CASE WHEN type = 'Income'  THEN amount END), 0) AS income,
                  COALESCE(SUM(CASE WHEN type = 'Expense' THEN amount END), 0) AS expense
             FROM transactions
            WHERE user_id = ?
            GROUP BY month`,
        )
        .all(userId)
        .map((r) => [r.month, r]),
    );

    for (let back = 5; back >= 0; back--) {
      const cursor = new Date(Date.UTC(year, monthNumber - 1 - back, 1));
      const key = `${cursor.getUTCFullYear()}-${String(
        cursor.getUTCMonth() + 1,
      ).padStart(2, '0')}`;
      const found = rowsByMonth.get(key);
      trend.push({
        month: key,
        label: `${MONTH_LABELS[cursor.getUTCMonth()]} ${cursor.getUTCFullYear() % 100}`,
        income: round(found?.income ?? 0),
        expense: round(found?.expense ?? 0),
      });
    }

    const budgetRow = req.db
      .prepare('SELECT amount FROM budgets WHERE user_id = ? AND month = ?')
      .get(userId, month);

    res.json({
      month,
      totals: {
        income: round(income),
        expense: round(expense),
        balance: round(income - expense),
      },
      monthTotals: {
        income: round(monthTotals.income),
        expense: round(monthTotals.expense),
      },
      budget: budgetRow ? budgetRow.amount : 0,
      expenseByCategory,
      incomeByCategory,
      trend,
      transactionCount: all.length,
    });
  });

  return router;
}