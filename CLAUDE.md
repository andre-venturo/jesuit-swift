# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

Jesuit (`api.wizhub.id`) is a SwiftUI iOS accounting app for the Serikat Jesus organization. UI copy is **Indonesian** ("Penerimaan" = cash receipts, "Pengeluaran" = disbursements/expenses, "Kontak" = contacts, "Neraca" = balance sheet, "Arus Kas" = cash flow, "Laba Rugi" = profit/loss). Deployment target iOS 17.6. Single target, single scheme — both named `Jesuit`. No test target exists.

## Build & Run

```bash
# Build (no iPhone 16 sim installed; use an available one — check `xcrun simctl list devices`)
xcodebuild -scheme Jesuit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Surface only the verdict
xcodebuild -scheme Jesuit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"

# Bump build number (both Debug+Release CURRENT_PROJECT_VERSION + Info.plist)
xcrun agvtool next-version -all
```

The `skipping cache due to an error: Couldn't fetch updates from remote repositories` lines during build are benign SPM cache warnings, not failures. `⚠️ Inject: InjectionIII bundle not found` and simulator `RBLayer: unable to create texture` / `IOSurface` logs at runtime are also harmless.

## Architecture

Clean-ish layering: **Presentation → Domain (protocols + entities) → Data (repositories) → Core (network, DI, storage)**. Dependencies point inward via protocols in `Domain/Protocols/`; concrete repositories in `Data/Repositories/` are wired in DI.

### Dependency injection (Swinject)

`AppDI.shared` (`Core/DI/AppDI.swift`) is the single Swinject container. Everything — network service, repositories, presenters, shared state (`AuthSession`, `AppTabRouter`, `NavigationService`) — is registered here. Two ways to obtain a dependency:

- `AppDI.shared.resolver(SomeType.self)` — used in views' `@State private var presenter = AppDI.shared.resolver(HomePresenter.self)`.
- `@Injected private var x: SomeType` (`Core/DI/Injected.swift`) — property wrapper resolving from the same container.

Presenters needing a runtime argument get a dedicated factory method on `AppDI` (e.g. `cashReceiptDetailPresenter(id:)`). Add new dependencies by registering in `AppDI.init` first.

### Presenters (the "VM" layer)

`@Observable @MainActor final class XPresenter`. They depend on repository **protocols**, not concretes. Async state is modeled with the generic `AppState<T>` enum (`idle / empty / loading / refreshing / loadmore / success(T) / error`). Convention: store `private(set) var state: AppState<T>`, expose computed accessors (`isLoading`, `errorMessage`, `detail`) that pattern-match the state. Error copy goes through `LoginPresenter.message(for:)`.

### Networking

`NetworkService` is an `actor` conforming to `NetworkServiceProtocol`. Three entry points: `requestDecoded` (JSON body → `T`), `request` (→ `APIResponse<T>` envelope), and `requestMultipartDecoded` (file uploads as `attachments_n` parts). Bearer token is read from `TokenKeychainActor.shared` per-request and attached when `endpoint.requiresAuth`.

**Two base URLs** in `Core/Constants/AppURLConstants.swift`: `baseURL` (`…/core/v1` — auth, users, branches) and `financeBaseURL` (`…/finance/v1` — contacts, cash-transactions, accounts). Repositories pass `baseURL:` explicitly per call to pick the right host. All endpoint paths are centralized in `AppURLConstants.Auth` / `.Finance`.

### Navigation

Two independent layers:
- **Root flow** uses **UIPilot** via `NavigationService` (`@Observable`, `var pilot`) with the `AppRoute` enum (`login / home / …`). `AppCoordinator` is the root view. This is auth/launch gating.
- **In-tab navigation** is plain SwiftUI: `MainTabScreen` is a `TabView` bound to `AppTabRouter.selection` (`MainTab`: `home, kontak, penerimaan, pengeluaran, more`). **Each tab is wrapped in its own `NavigationStack`** in `MainTabScreen`, so full-page screens (detail views, create/edit forms, the org switcher, the approval inbox) **push** via `.navigationDestination(isPresented:)` / `.navigationDestination(item:)` rather than `.sheet`. This was deliberate — `.sheet` stacked sheet-on-sheet (list → detail → edit) and got cramped. Pushed pages rely on the native back chevron (no manual "Tutup" button), and list screens keep `.toolbar(.hidden, for: .navigationBar)` so no stray title bar shows. **Tab-bar hiding: the pushed page must NOT own `.toolbar(.hidden, for: .tabBar)`** — the pushed view is torn down mid-pop, the modifier dies early, and the tab bar blinks back in before the transition finishes. Instead the **tab-root screen** (which never leaves the hierarchy) drives visibility off its push state: `.toolbar(selected == nil ? .visible : .hidden, for: .tabBar)` (see `PenerimaanScreen`/`MoreScreen`; nested pushes like Laporan → PDF preview are covered because the root's flag stays set the whole time). `navigationDestination(item:)` needs a **Hashable** item — list screens use a small `Identifiable, Hashable` id-wrapper. **Only leaf pickers stay `.sheet`** (with `.presentationDetents`): `FilterBySheet`, `AssetFilterSheet`, `CashFlowRangeSheet`, `SelectionField`/`SelectionSheet`, Neraca's date picker, Laporan's filter, `ShareSheet`, the line editors (`EditReceiptLineSheet`/`EditLineSheet`), and `ImagePreviewSheet` (a `fullScreenCover`). For a new detail/edit page, follow the **push** pattern; for a new single-select picker, use `.sheet` + `FilterBySheet`.

### Penerimaan & Pengeluaran share one detail sheet

`CashReceiptDetailSheet` renders **both** receipts and disbursements, switched by its `kind: .receipt | .disbursement` parameter (it decides which edit sheet — `CreateReceiptSheet` vs `CreateExpenseSheet` — to present). The two create sheets are near-duplicates with parallel `EditLineSheet` / `EditReceiptLineSheet` line editors. When changing one, check whether the other needs the same change.

### List tabs: pagination, filtering — all client-side

The cash-transactions and contacts list endpoints take only `page`/`limit` (+ `transaction_type`) — **no server-side sort, filter, or search params**. So the Kontak / Penerimaan / Pengeluaran presenters do all of it client-side over the loaded pages:
- **Load-more:** presenters track `page`/`totalPages` and expose `loadMore()` + `isLoadingMore`/`canLoadMore` (reusing `AppState.loadmore`). Each screen fires `loadMore()` from the **last row's `.onAppear`** (not a footer — `RowDivider` renders nothing for the last row). Appended pages are **deduped by id** (the API can repeat a row across page boundaries when timestamps tie).
- **Filter chips / search** in `filtered` are computed over `receipts`/`contacts`; load-more therefore pages the *unfiltered* set.
- There is **no list sort UI** — it was removed because the endpoint can't sort and client re-sorting reshuffled rows during load-more. `ListTopBar.onOpenSort` is optional (nil hides the button).

### Laporan (report)

`LaporanScreen` + `LaporanPresenter` render a cash journal ("Laporan Arus Kas", Jurnal Umum-style). It sweeps **every** page of receipts + disbursements once, caches them, and re-aggregates client-side per selected period (period changes never hit the network). Output is a Debit (penerimaan) / Kredit (pengeluaran) `JournalEntry` table under a company header. The period selector is a **pinned bar** (`safeAreaInset(edge: .top)`): prev/next stepper buttons around a borderless `Menu` holding an optional-selection `Picker` (nothing checked while a custom range is active — the checkmark moves to "Rentang Khusus…"). Filters (Status / Cabang & Unit / Akun) live in a medium-detent bottom sheet built from `FormCard` + `FormPickerRow` rows, each opening its searchable `SelectionSheet`; a prepended `id == ""` "Semua" option clears the filter **and** keeps `FormPickerRow`'s auto-select-single-option from silently applying one. Account/branch **names** are resolved from `fetchCashAccounts()`/`fetchBranches()` because the list payload carries only ids (`CashReceipt.cashAccountId` / `branchId`). Export to **PDF + CSV** via `ReportExporter` (`Core/Utils/` — native `UIGraphicsPDFRenderer` + RFC-4180 CSV with UTF-8 BOM, no third-party deps). Exports honor the active filters. `LaporanScreen` is **pushed** from `MoreScreen` (not a sheet); the PDF export **pushes** `PDFPreviewPage` (PDFKit `PDFView` + `ShareLink` — QuickLook's own toolbar buttons don't survive being pushed inside a SwiftUI stack); CSV still goes through `ShareSheet` (a `UIActivityViewController` wrapper).

## UI conventions

- **Fonts:** never use `.font(.system…)` for text. Use `Text(...).customFont(weight, size)` (`Commons/Extensions/CustomFont.swift`) with sizes from the `Typography` enum (`Commons/Theme/AppTheme.swift`: `display 28 → caption2 11`). Weights: `.regular/.medium/.semibold/.bold`. Note Inter's bold style is `"Semi Bold"`/`"Extra Bold"` (with space).
- **Colors:** semantic tokens only — `.title`, `.subtitle`, `.accent`, `.income` (green), `.expense` (red), `.background1`, `.textFieldBG` (defined as color sets in `Assets.xcassets/Colors` + `AppTheme`). Don't hardcode hex except via the `Color(hex:)` helper.
- **Currency:** `Double` extensions in `Core/Utils/Formatters.swift` — `asRupiah` ("Rp 1.200.000"), `asIDR` ("IDR…"), `asSignedRupiah`, `groupedThousands` (digit-string grouping for input fields). `CurrencyField` binds a digits-only string.
- **Grouped forms:** build with the `FormCard` primitives (`Components/FormCard.swift`): `FormPickerRow`, `FormFieldRow`, `FormCurrencyRow`, `FormTextAreaRow`, `FormDateRow`, `FormToggleRow` — Zoho-style label-left/value-right rows with inset dividers. Required-field labels render in `.expense` red.
- **Shared list rows** (`ListMetrics` in `AppTheme`) are used by Kontak / Penerimaan / Pengeluaran rows; changing those tokens affects all three. To restyle one list only, override inline (e.g. `ListMetrics.titleSize - 2`).
- **Selection sheets:** for a single-select picker, present `FilterBySheet` (`Components/FilterBySheet.swift`) — a `[FilterOption]` list with checkmark + optional count badge — rather than an inline `Menu` (menus get unusable with long lists). Convention: an `id == ""` option means "Semua" (clear/all). (The old floating-label outlined filter fields are gone — filter fields are `FormPickerRow`s inside a `FormCard`, see `LaporanScreen`'s filter sheet.)
- Apply `.hotReloadable()` to a screen's body for Inject live-reload in DEBUG (requires the InjectionIII app running; harmless if absent).

## Git

End commit messages with the Co-Authored-By trailer per the harness instructions. Don't commit/push unless asked.
