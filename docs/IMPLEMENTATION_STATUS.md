# Implementation Status

_Last updated: 2026-06-17_

Audit of what is **not** implemented, integrated, or wired in the Jesuit iOS app.
Legend: ✅ real backend · ⚠️ partial · ❌ stub/fake/dead.

---

## Done today (2026-06-17)

- ✅ **Organisation switcher revamp** — header org button opens `OrganizationSwitcherSheet` (iOS-style picker: card of rows, avatar, "Type • Role" subtitle, active checkmark) replacing the old `Menu`. `GET /auth/companies` + `POST /auth/switch-company`.
- ✅ **Company create** — `POST /companies` `{name, type, parent_id}` via `CreateCompanySheet` ("Perusahaan Baru", Tipe + Induk pickers), opened from the sheet's "Kelola" button.
- ✅ **Company edit / delete** — per-row "…" menu: Ubah (`PUT /companies/{id}`), Hapus (`DELETE /companies/{id}`, confirm alert, hidden on active company), Anak Perusahaan (new subsidiary preset under that parent). `CreateCompanySheet.Mode` = create/edit/subsidiary.
- ✅ **Neraca (balance sheet) summary** — Home summary card now shows Harta / Kewajiban / Modal from `dashboard/balance-sheet-summary`, replacing the hardcoded Receivables/Payables + Overdue cards.
- 🔧 **TestFlight deploy** — `scripts/testflight.sh` (archive → export → altool upload), `ExportOptions.plist`, `PrivacyInfo.xcprivacy`, `docs/TESTFLIGHT.md`. Bundle id `com.jesuit`, team `RTJ97ZPCBQ`.

---

## Done (2026-06-15)

- ✅ **Penerimaan create** — `POST /cash-transactions/submit` (type=receipt) via `CreateReceiptSheet`.
- ✅ **Penerimaan detail + actions** — `GET {id}`, Setujui (`approve`), Tolak (`reject`), Hapus (`DELETE`), Ubah (`PUT`), role/status-gated. Hapus allowed in any status; gating uses raw API status.
- ✅ **Kontak create** — `POST /contacts`; **Kontak update** — `PUT /contacts/{id}` (tap row to edit).
- ✅ **Rekening Kas & Bank** widget — `dashboard/cash-accounts`.
- ✅ **Cash Flow** revamp — Laba Rugi + Arus Kas panels (`profit-loss-cash-flow`), month stepper, 6 presets, custom range, Date x-axis, monthly-merged series.
- ✅ **Quick Create** → real features (Penerimaan/Pengeluaran/Kontak) via `AppTabRouter`.
- ✅ **Home pull-to-refresh**; `CurrencyField` formatting fix; `AuthSession.roles` → `isAdministrator`.

---

## A. Hardcoded data shown as real

All in [`HomePresenter.swift`](../Jesuit/Presentation/Presenters/HomePresenter.swift):

| Item | Status | Notes |
|------|--------|-------|
| Total Receivables / Payables | ❌ | Always `0`, never fetched. No longer shown on Home (summary card is now Neraca). Properties still dead. |
| Overdue Invoices / Bills | ❌ | Always `0`, never fetched. No longer shown on Home. |
| `kpis` | ❌ | Fake values. Not rendered (dead). |
| `cashflow` array | ❌ | Fake Jan–Jun. Not rendered (real chart uses `cashFlowSeries`). |
| `invoices` | ❌ | Fake (Globex, Initech…). Not rendered. |
| `expenses` | ❌ | Fake (Figma, Delta…). Not rendered. |
| `unbilledHours` / `unbilledExpenses` | ❌ | Project Summary metrics = 0. Section removed from Home. |
| `userName` / `organization` | ⚠️ | Falls back to `"Andre"` / `"Venturo"` when signed out. |

## B. Stub UI actions (do nothing)

| Action | Location | Notes |
|--------|----------|-------|
| Header bell button | `HomeScreen.swift` | Empty `{}`. |
| Org switcher footer extras | `OrganizationSwitcherSheet.swift` | Mockup "+ Perusahaan" footer + "Lihat Perusahaan terhapus" (deleted-companies/restore) not built. |
| MoreScreen rows | `MoreScreen.swift` | Organisasi / Langganan / Pengaturan / Bantuan non-tappable; "Langganan: Pro" hardcoded. |
| Forgot Password "send" | [`ForgotPasswordScreen.swift`](../Jesuit/Presentation/Screens/Auth/ForgotPassword/ForgotPasswordScreen.swift) | No endpoint; just `popTo(.home)`. Presenter holds only `emailText`. |
| Reset Password submit | `ResetPasswordPresenter.swift` | 3 empty strings, no logic. |
| Pengeluaran row tap | `PengeluaranScreen.swift` | No detail sheet (Penerimaan has one; Pengeluaran does not). |

## C. Dead / unused code

**Orphaned component files (0 references):**
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

**Unused routes:** `AppRoute.err` — defined, never navigated to.

> `CashFlowRangeSheet.swift` and `ContactRepository.fetchCategories()` are no longer dead — both wired today (custom range + Kontak category picker).

## D. Partially wired (real backend, incomplete)

| Feature | Status | Notes |
|---------|--------|-------|
| Penerimaan list / create / detail / approve / reject / delete / edit | ✅ | Fully wired. |
| Kontak list / create / update | ✅ | Fully wired. No delete (no endpoint). |
| Pengeluaran list / create | ✅ | Create via `CreateExpenseSheet`. No detail/approve/reject/delete yet. |
| Cash Flow card + Rekening Kas & Bank + Neraca | ✅ | `daily-revenue` + `profit-loss-cash-flow` + `cash-accounts` + `balance-sheet-summary`. |
| Login / Register / logout / company switch / restoreSession | ✅ | Real. |
| Company create / edit / delete / add subsidiary | ✅ | `POST/PUT/DELETE /companies`. Active company can't be deleted. |
| Reset password screen | ⚠️ | Reachable in coordinator, no logic. |
| Log Aktivitas tab (Penerimaan detail) | ❌ | `audit-logs` + `approval-requests/by-doc` endpoints known, tab not built. |

---

## Priority gaps to production

1. **Pengeluaran detail/actions** — mirror the Penerimaan detail sheet (approve/reject/delete/edit).
2. **Log Aktivitas tab** — `audit-logs` + `approval-requests/by-doc` for the Penerimaan detail.
3. **Forgot / Reset password** — wire to real endpoints.
4. **Org switcher footer** — "+ Perusahaan" + "Lihat Perusahaan terhapus" (deleted/restore) to match mockup.
5. **Dead-code cleanup** — remove ~9 orphaned component files + unused presenter arrays (`kpis`, `cashflow`, `invoices`, `expenses`, receivables/payables/overdue).
