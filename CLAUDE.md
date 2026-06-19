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
- **In-tab navigation** is plain SwiftUI: `MainTabScreen` is a `TabView` bound to `AppTabRouter.selection` (`MainTab`: `home, kontak, penerimaan, pengeluaran, more`). Screens present detail/edit via `.sheet`, not pushes — `HomeScreen` hides its nav bar entirely. Follow the sheet pattern for new detail/full-list pages.

### Penerimaan & Pengeluaran share one detail sheet

`CashReceiptDetailSheet` renders **both** receipts and disbursements, switched by its `kind: .receipt | .disbursement` parameter (it decides which edit sheet — `CreateReceiptSheet` vs `CreateExpenseSheet` — to present). The two create sheets are near-duplicates with parallel `EditLineSheet` / `EditReceiptLineSheet` line editors. When changing one, check whether the other needs the same change.

## UI conventions

- **Fonts:** never use `.font(.system…)` for text. Use `Text(...).customFont(weight, size)` (`Commons/Extensions/CustomFont.swift`) with sizes from the `Typography` enum (`Commons/Theme/AppTheme.swift`: `display 28 → caption2 11`). Weights: `.regular/.medium/.semibold/.bold`. Note Inter's bold style is `"Semi Bold"`/`"Extra Bold"` (with space).
- **Colors:** semantic tokens only — `.title`, `.subtitle`, `.accent`, `.income` (green), `.expense` (red), `.background1`, `.textFieldBG` (defined as color sets in `Assets.xcassets/Colors` + `AppTheme`). Don't hardcode hex except via the `Color(hex:)` helper.
- **Currency:** `Double` extensions in `Core/Utils/Formatters.swift` — `asRupiah` ("Rp 1.200.000"), `asIDR` ("IDR…"), `asSignedRupiah`, `groupedThousands` (digit-string grouping for input fields). `CurrencyField` binds a digits-only string.
- **Grouped forms:** build with the `FormCard` primitives (`Components/FormCard.swift`): `FormPickerRow`, `FormFieldRow`, `FormCurrencyRow`, `FormTextAreaRow`, `FormDateRow`, `FormToggleRow` — Zoho-style label-left/value-right rows with inset dividers. Required-field labels render in `.expense` red.
- **Shared list rows** (`ListMetrics` in `AppTheme`) are used by Kontak / Penerimaan / Pengeluaran rows; changing those tokens affects all three. To restyle one list only, override inline (e.g. `ListMetrics.titleSize - 2`).
- Apply `.hotReloadable()` to a screen's body for Inject live-reload in DEBUG (requires the InjectionIII app running; harmless if absent).

## Git

End commit messages with the Co-Authored-By trailer per the harness instructions. Don't commit/push unless asked.
