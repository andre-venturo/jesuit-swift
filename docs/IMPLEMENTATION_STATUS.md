# Implementation Status

_Last audited: 2026-06-15_

Audit of what is **not** implemented, integrated, or wired in the Jesuit iOS app.
Legend: ✅ real backend · ⚠️ partial · ❌ stub/fake/dead.

---

## A. Hardcoded data shown as real

All in [`HomePresenter.swift`](../Jesuit/Presentation/Presenters/HomePresenter.swift):

| Item | Location | Status | Notes |
|------|----------|--------|-------|
| Total Receivables / Payables | `:96-97` | ❌ | Always `0`, never fetched. Home balance card empty. |
| Overdue Invoices / Bills | `:98-99` | ❌ | Always `0`, never fetched. |
| `kpis` | `:108-113` | ❌ | Fake values. Not rendered (dead). |
| `cashflow` array | `:115-122` | ❌ | Fake Jan–Jun. Not rendered (real chart uses `cashFlowSeries`). |
| `invoices` | `:276` | ❌ | Fake (Globex, Initech…). Not rendered. |
| `expenses` | `:283` | ❌ | Fake (Figma, Delta…). Not rendered. |
| `unbilledHours` / `unbilledExpenses` | `:140-141` | ❌ | Project Summary metrics = 0. |
| `userName` / `organization` | `:36` | ⚠️ | Falls back to `"Andre"` / `"Venturo"` when signed out. |

## B. Stub UI actions (do nothing)

| Action | Location | Notes |
|--------|----------|-------|
| Penerimaan ＋ button | [`PenerimaanScreen.swift:73`](../Jesuit/Presentation/Screens/Penerimaan/PenerimaanScreen.swift#L73) | Empty — `// Hook up create-receipt`. |
| Kontak ＋ button | [`KontakScreen.swift:73`](../Jesuit/Presentation/Screens/Kontak/KontakScreen.swift#L73) | Empty — `// Hook up create-customer`. |
| Project Summary "Log Time" | [`HomePresenter.swift:165`](../Jesuit/Presentation/Presenters/HomePresenter.swift#L165) | Just resets timer. (Section currently removed from Home.) |
| Header bell button | `HomeScreen.swift` | Empty `{}`. |
| MoreScreen rows | `MoreScreen.swift` | Organisasi / Langganan / Pengaturan / Bantuan non-tappable; "Langganan: Pro" hardcoded. |
| Forgot Password "send" | [`ForgotPasswordScreen.swift:42`](../Jesuit/Presentation/Screens/Auth/ForgotPassword/ForgotPasswordScreen.swift#L42) | No endpoint; just `popTo(.home)`. Presenter holds only `emailText`. |
| Reset Password submit | `ResetPasswordPresenter.swift` | 3 empty strings, no logic. |

## C. Dead / unused code

**Orphaned component files (0 references):**
- `CashFlowRangeSheet.swift`
- `TopExpensesCard.swift`
- `CashflowCard.swift`
- `KPICard.swift`
- `InvoiceRow.swift`
- `ExpenseRow.swift`
- `SummaryBanner.swift`
- `SearchPeriodBar.swift`
- `StatusFilterTabs.swift`
- `ProjectSummaryCard.swift` (only referenced from the now-removed Home section)

**Unused presenter data:** `kpis`, `cashflow`, `invoices`, `expenses` (never displayed).

**Unused repo methods:**
- `ContactRepository.fetchCategories()` — never called.
- `LoginRepositoryProtocol` — commented-out placeholder file.

**Unused routes:** `AppRoute.err` — defined, never navigated to.

## D. Partially wired (real backend, incomplete)

| Feature | Status | Notes |
|---------|--------|-------|
| Penerimaan / Pengeluaran / Kontak lists | ✅ | Real fetch, search, sort, pull-to-refresh. |
| Pengeluaran create | ✅ | Only fully-working create flow (`CreateExpenseSheet` → `submit`/`saveDraft`). |
| Cash Flow card + Cash & Bank | ✅ | `daily-revenue` + `profit-loss-cash-flow` + `cash-accounts`. |
| Login / Register / logout / company switch / restoreSession | ✅ | Real. |
| Reset password screen | ⚠️ | Reachable in coordinator, no logic. |

---

## Priority gaps to production

1. **Dashboard summary numbers** — receivables/payables/overdue need endpoints + wiring.
2. **Create flows** for Penerimaan and Kontak (copy the Pengeluaran `CreateExpenseSheet` pattern).
3. **Forgot / Reset password** — wire to real endpoints.
4. **Dead-code cleanup** — remove ~9 orphaned component files + unused presenter arrays.
