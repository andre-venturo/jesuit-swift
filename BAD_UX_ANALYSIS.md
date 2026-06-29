# Bad UX Analysis — Jesuit

## Context
Audit of the Jesuit SwiftUI accounting app for bad UX. Three explore passes (screens, presenters, components) surfaced ~80 raw findings; I verified the high-impact ones against source and dropped the noise (e.g. "no negative amounts breaks accounting" — false, transaction type carries the sign; "sheet-on-sheet" — normal iOS). What remains below is verified and prioritized. This is a findings report with a recommended fix order, not a from-scratch redesign.

---

## Tier 1 — Real, broad, worth fixing

### 1. Dynamic Type is disabled app-wide
`Commons/Extensions/CustomFont.swift:22-35` — every font uses `Font.custom(..., fixedSize: size)`. `fixedSize` opts out of iOS text scaling, so a low-vision user who bumps system text size sees **no change anywhere** in the app. Since CLAUDE.md mandates `.customFont()` for all text, this is universal.
- Fix: switch `fixedSize:` → `size:` (relative scaling), or use `.custom(_:size:relativeTo:)`. One-file change, app-wide effect. Spot-check layouts that assume fixed line heights.

### 2. Required fields signalled by red color only
`Components/FormCard.swift:60` — `.foregroundStyle(required ? Color.expense : Color.title)`. Colorblind/VoiceOver users get no cue which fields are mandatory. Combined with #3, forms are guesswork.
- Fix: add an asterisk or "(wajib)" suffix to required labels; one edit in FormCard, propagates everywhere.

### 3. Validation only fires on submit, no inline/field-level feedback
Submit buttons across `CreateReceiptSheet` / `CreateExpenseSheet` / `CreateAssetSheet` are `.disabled(!canSave)` and dimmed to 0.5 with **no explanation of what's missing**. Local errors (amount = 0, no lines) stay silent until the user taps save and waits for the async round-trip. Only `ChangePasswordPresenter` has a `validationHint`.
- Fix: expose a `validationHint` computed property on the create presenters (mirror ChangePassword) and render it near the disabled button. Per-field highlighting is a bigger lift — defer.

### 4. No retry affordance from list error states
`PenerimaanPresenter` (and Pengeluaran/Kontak/Transfer/Asset peers) move to `.error` on load failure but expose only `errorMessage` — no `retry()`. User must leave the tab and come back. Error copy is also generic ("Terjadi kesalahan. Coba lagi.") via `NetworkError`/`LoginPresenter.message(for:)`.
- Fix: add a `retry()` that re-calls `load()`, and a button in each screen's error view. Small, repeated pattern.

### 5. Zero accessibility labels in the codebase
No `.accessibilityLabel` usages anywhere. Icon-only buttons (filter/sort/close/trash) are unlabeled to VoiceOver; income/expense conveyed by green/red with no text alternative (`CashAccountsCard`, `KPICard`).
- Fix: label the icon buttons and amount rows. Incremental; start with the most-used controls (ListTopBar, detail-sheet toolbar, delete).

---

## Tier 2 — Localized but genuine

### 6. Silent export failure in Laporan
`LaporanScreen.swift:228-230` — PDF/CSV export `catch {}` does nothing (ponytail-commented). If `ReportExporter` throws, the share sheet just never appears and the user has no idea why.
- Fix: set an `errorMessage`/alert on catch. ~3 lines. (The ponytail call was "not worth a dialog" — disagree for an explicit user-initiated export; a failed tap with zero feedback reads as a frozen button.)

### 7. Laporan / ApprovalInbox sweep every page before showing anything
`LaporanPresenter.fetchAll` (`:241-256`) loops up to `maxPages` (50) × `pageSize` (100) per type, blocking on both before first paint. On a large dataset that's a multi-second blank spinner. This is forced by the API (no server-side aggregation), so it's a constraint, not a bug — but it deserves a progress hint ("Memuat 1.200 transaksi…") instead of a bare spinner.
- Fix: surface page/record progress during the sweep. Low effort, removes the "is it stuck?" feeling.

### 8. Client-side filter/search only sees loaded pages
List presenters filter/search over `receipts`/`contacts` which hold only the pages loaded so far. A search for a row on page 5 returns "empty" until the user has scrolled that far. Tab badges use server `counts.*` so badge and filtered list disagree. Architectural (CLAUDE.md documents the endpoint has no server filter) — flag, don't necessarily fix now.

### 9. Destructive line delete with no confirmation
`CashReceiptDetailSheet.swift:238-242` — trash icon on a form line deletes instantly mid-entry. Header-level deletes do confirm; line deletes don't.
- Fix: confirmation alert, or an undo snackbar. Match the existing delete-confirm pattern.

### 10. Unsaved-changes lost on sheet close
Create/edit sheets ("Tutup"/"Batal") dismiss without warning when fields are dirty (`CreateReceiptSheet`, `ChangePasswordSheet`). Easy accidental data loss on a long form.
- Fix: `.interactiveDismissDisabled` + a discard-confirmation when the form is dirty.

---

## Tier 3 — Polish / note only (don't block on these)
- No success feedback (toast/haptic) after save — sheet just closes; user unsure it worked.
- Multi-submit possible: save buttons show a spinner overlay but aren't disabled during the in-flight request → duplicate submissions on slow networks.
- Tap targets at 32×32 (`ListTopBar.swift:115`) below the 44pt HIG minimum.
- Partial attachment-upload failure shows a warning with no in-place retry — user must reopen the transaction.
- `CreateReceiptSheet` vs `CreateExpenseSheet` are ~415-line near-duplicates — not a UX bug per se, but guarantees the fixes above must be applied twice and risks drift.
- Foreign-currency exchange-rate input keyboard inconsistency (numberPad vs decimalPad) across sheets.

---

## Recommended fix order (if proceeding)
Do Tier 1 in this sequence — each is a small, mostly single-file change with app-wide payoff:
1. `CustomFont.swift` — `fixedSize:` → `size:` (Dynamic Type).
2. `FormCard.swift` — asterisk/"(wajib)" on required labels.
3. Add `retry()` + error-view button to the list presenters/screens (one pattern, repeated).
4. Add `validationHint` to create presenters; render near disabled save button.
5. Accessibility labels on icon-only controls, starting with ListTopBar + detail toolbars + delete.

Then Tier 2 items 6, 9, 10 (each ~handful of lines).

## Verification
- Build: `xcodebuild -scheme Jesuit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`
- Dynamic Type: Settings → Accessibility → Larger Text, confirm app text scales.
- VoiceOver: enable, swipe through a list + a create sheet, confirm controls announce.
- Validation: open a create sheet empty, confirm the hint explains the disabled save.
- Error/retry: airplane mode, open Penerimaan, confirm a retry button appears and works.
