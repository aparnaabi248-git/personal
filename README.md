# Personal Finance Tracker

A local-first personal finance tracker built with Flutter. Track income and
expenses, set a monthly budget, and explore reports — all stored on the device,
no backend required.

## Screens

| Route            | Screen                | What it does                                        |
| ---------------- | --------------------- | --------------------------------------------------- |
| `/login`         | Login                 | Sign in to the account stored on this device        |
| `/register`      | Create Account        | Create the single local account                     |
| `/home`          | Overview              | Dashboard: KPI tiles, balance, charts, activity feed |
| `/addTransaction` | Add / Edit Transaction | Record an income or expense                        |
| `/history`       | Transactions          | Search, filter, edit and delete entries             |
| `/budget`        | Budget                | Set a monthly limit and track this month's spend     |
| `/reports`       | Reports               | Category breakdown and all-time totals              |
| `/profile`       | Profile               | Edit name, email, phone and address                 |
| `/settings`      | Settings              | Currency, reminders, sample data, data wipe, logout |

## Running it

```bash
flutter pub get

# Web (production build, then serve it)
flutter build web --no-wasm-dry-run
powershell -ExecutionPolicy Bypass -File tool\serve_web.ps1 -Port 8081

# Or the dev server
flutter run -d chrome

# Tests and static analysis
flutter analyze
flutter test
```

`tool/serve_web.ps1` is a dependency-free static server for `build/web`. It sets
the MIME types Flutter needs and disables caching so a rebuild shows up on
refresh.

## How it is put together

```
lib/
  main.dart                  App root, theme, routes
  theme/app_theme.dart       Colour tokens, gradients, ThemeData
  models/                    Transaction, User, Budget, Currency
  providers/finance_provider.dart   Single source of truth + persistence
  widgets/
    app_shell.dart           Sidebar + top bar chrome shared by every screen
    dashboard_card.dart      Small summary tile
    dashboard_button.dart    Dashboard action tile
    transaction_card.dart    History row with edit/delete menu
    custom_button.dart       Loading-aware primary button
  screens/                   One file per screen
```

`FinanceProvider` is a `ChangeNotifier` that owns all state and persists to
`SharedPreferences`. Screens read it with `context.watch` and mutate it through
its methods, so there is a single source of truth and money is formatted in one
place (`money`, `moneyShort`, `moneySigned`) respecting the selected currency.

`AppShell` owns navigation. Every screen hands it a title and its active route,
so the sidebar highlights correctly and back-navigation behaves the same
everywhere. Below 1000px the sidebar becomes a drawer; the dashboard collapses
to a single column below 1100px of body width.

## Data and privacy

Everything is stored locally via `SharedPreferences` — transactions, budget,
profile, currency and preferences. Nothing is uploaded. The account is a single
local account: registering twice is refused so the stored credentials cannot be
silently overwritten. "Clear All Data" wipes finances but keeps you signed in;
"Logout" keeps your data and ends the session.