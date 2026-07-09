# Jesuit

SwiftUI iOS accounting app for the **Serikat Jesus** organization, talking to the WizHub backend (`api.wizhub.id`). This README is the onboarding entry point for the next developer: what the app is, how to build it, how it's laid out, and the conventions and gotchas that will bite you if you don't know them.

> The app's **UI copy is Indonesian**; the code, comments, and these docs are English. See the [glossary](#glossary) below to map terms.

---

## Table of contents

- [Overview](#overview)
- [Glossary](#glossary)
- [Tech stack](#tech-stack)
- [Getting started](#getting-started)
- [Project configuration](#project-configuration)
- [Architecture](#architecture)
- [Directory layout](#directory-layout)
- [Dependency injection](#dependency-injection)
- [Networking](#networking)
- [Navigation](#navigation)
- [Shared state](#shared-state)
- [Feature modules](#feature-modules)
- [Data layer](#data-layer)
- [Reports subsystem](#reports-subsystem)
- [UI conventions](#ui-conventions)
- [Key gotchas](#key-gotchas)
- [Contributing](#contributing)
- [Documentation index](#documentation-index)

---

## Overview

Jesuit is an internal accounting app: cash receipts and disbursements, fund transfers, contacts, fixed assets, a chart of accounts, an approval workflow, a dashboard, and a suite of financial reports. It is multi-company (a holding + subsidiaries) with a company switcher and per-user role/permission gating.

- **Platform:** iOS 17.6+, iPhone + iPad.
- **Target/scheme:** single target and scheme, both named `Jesuit`.
- **Tests:** there is **no test target**.
- **Appearance:** forced **dark mode** (`.preferredColorScheme(.dark)` in [JesuitApp.swift](Jesuit/App/JesuitApp.swift)).

## Glossary

| Indonesian (UI) | English |
|---|---|
| Penerimaan | Cash receipts |
| Pengeluaran | Disbursements / expenses |
| Transfer Dana | Fund transfers |
| Kontak | Contacts |
| Aset | Fixed assets |
| Master Akun | Chart of accounts |
| Persetujuan | Approvals (inbox) |
| Laporan | Reports |
| Jurnal Umum | General journal |
| Buku Besar | General ledger |
| Neraca | Balance sheet |
| Laba Rugi | Profit & loss |
| Arus Kas | Cash flow |
| Cabang / Unit | Branch / unit |

## Tech stack

- **Language / UI:** Swift 6.0, SwiftUI.
- **Dependencies** (SwiftPM, pinned in [Package.resolved](Jesuit.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved)):

| Package | Version | Purpose |
|---|---|---|
| [Swinject](https://github.com/Swinject/Swinject) | 2.10.0 | Dependency injection container |
| [UIPilot](https://github.com/canopas/UIPilot) | 2.0.2 | Root navigation (also **vendored** at [Core/Vendor/UIPilot](Jesuit/Core/Vendor/UIPilot)) |
| [Inject](https://github.com/krzysztofzablocki/Inject) | 1.6.0 | Hot reload in DEBUG (via `.hotReloadable()`) |
| [OSLogViewer](https://github.com/0xWDG/OSLogViewer) | 1.1.3 | In-app log viewing |

No CocoaPods, no Carthage — pure SwiftPM.

## Getting started

Requires Xcode with a Swift 6 toolchain. Open `Jesuit.xcodeproj` and run, or use the CLI:

```bash
# List installed simulators (no iPhone 16 sim is assumed to exist — pick an available one)
xcrun simctl list devices

# Build
xcodebuild -scheme Jesuit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build

# Build, surfacing only the verdict
xcodebuild -scheme Jesuit -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build 2>&1 \
  | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"

# Bump build number (Debug + Release CURRENT_PROJECT_VERSION + Info.plist CFBundleVersion)
xcrun agvtool next-version -all
```

**Benign noise you can ignore:**
- `skipping cache due to an error: Couldn't fetch updates from remote repositories` — SPM cache warning, not a failure.
- `⚠️ Inject: InjectionIII bundle not found` — only present when the InjectionIII app is running; harmless if absent.
- Simulator `RBLayer: unable to create texture` / `IOSurface` logs at runtime — harmless.
- `xcrun agvtool next-version -all` prints `Cannot find ".../YES"` — an agvtool quirk; the version bump still succeeds.

For TestFlight archive → export → upload, see [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md).

## Project configuration

From [project.pbxproj](Jesuit.xcodeproj/project.pbxproj) and [Info.plist](Jesuit/Info.plist):

| Setting | Value |
|---|---|
| Bundle identifier | `com.jesuit` |
| Development team | `RTJ97ZPCBQ` |
| Marketing version | `1.0.0` |
| Build number (`CURRENT_PROJECT_VERSION`) | `14` |
| Deployment target | iOS 17.6 |
| Swift version | 6.0 |
| Device family | iPhone + iPad (`1,2`) |

**Base URLs** are in [AppURLConstants.swift](Jesuit/Core/Constants/AppURLConstants.swift):

- `baseURL` → `https://api.wizhub.id/core/v1` — auth, users, branches, companies, audit logs, approval requests.
- `financeBaseURL` → `https://api.wizhub.id/finance/v1` — contacts, cash-transactions, accounts, assets, fund-transfers, dashboard.

All endpoint paths are centralized under `AppURLConstants.Auth`, `.Finance`, `.Core`. Face ID is declared (`NSFaceIDUsageDescription`) and the app is export-encryption-exempt (`ITSAppUsesNonExemptEncryption=false`).

> **Known quirk:** `Info.plist`'s `UILaunchScreen` references color `MainColor`, but no `MainColor.colorset` exists in the asset catalog — the launch color resolves to a default. Pre-existing, cosmetic.

## Architecture

Clean-ish layering, dependencies pointing **inward** via protocols:

```
Presentation  →  Domain            →  Data              →  Core
(SwiftUI +       (protocols +          (repositories        (network, DI,
 presenters)      entities)             impl protocols)      storage, utils)
```

- **Domain** owns the protocols ([Domain/Protocols](Jesuit/Domain/Protocols)) and entities ([Domain/Entities](Jesuit/Domain/Entities)). Everything else depends on these interfaces, not concretes.
- **Data** ([Data/Repositories](Jesuit/Data/Repositories)) implements the repository protocols against `NetworkServiceProtocol`.
- **Presentation** uses an **MVP-style presenter** layer (the "VM"): `@Observable @MainActor final class XPresenter`, depending on repository **protocols**.

**Async state** is modeled with the generic `AppState<T>` enum ([Commons/State/AppState.swift](Jesuit/Presentation/Commons/State/AppState.swift)): `idle / empty / loading / refreshing / loadmore / success(T) / error`. Convention: presenters store `private(set) var state: AppState<T>` and expose computed accessors (`isLoading`, `errorMessage`, `detail`) that pattern-match it. Error copy is routed through `LoginPresenter.message(for:)`.

## Directory layout

154 Swift files under [Jesuit/](Jesuit):

```
Jesuit/
├── App/                    JesuitApp.swift (@main)
├── Core/
│   ├── DI/                 AppDI.swift, Injected.swift          (Swinject)
│   ├── Network/            NetworkService, Endpoint, HTTPMethod, APIResponse, NetworkError
│   ├── Constants/          AppURLConstants.swift, AppStrings.swift
│   ├── Storage/            Keychain/ (token), Biometric/
│   ├── Utils/              Formatters, ReportExporter, Validators, AppLogger, DeviceSize
│   ├── Logger/  Errors/  Env/(empty)
│   └── Vendor/UIPilot/     vendored copy of the UIPilot nav lib
├── Domain/
│   ├── Entities/           *Models.swift (Auth, CashReceipt, Contact, Asset, Account,
│   │                       Dashboard, DashboardCashFlow, FundTransfer, ActivityLog)
│   └── Protocols/          repository interfaces grouped by feature (+ Networks/)
├── Data/
│   ├── Repositories/       7 repositories (see Data layer)
│   └── DTOs/               (empty)
├── Presentation/
│   ├── AppNavigation/      AppCoordinator, AppRoute, NavigationService, DeepLinkHandler
│   ├── Presenters/         ~22 presenters (the VM layer)
│   ├── Screens/            feature screens (Auth, Home, Main, Kontak, Penerimaan,
│   │                       Pengeluaran, Transfer, Asset, MasterAkun, Laporan, More, Splash)
│   ├── Components/         ~25 reusable views (FormCard, CurrencyField, cards, rows, sheets)
│   └── Commons/            Theme, Extensions, Modifiers, Enums, State, Styles
└── Resources/
    ├── Catalogs/Assets.xcassets    colors, app icon, images
    └── Fonts/                      5 Inter .otf weights
```

## Dependency injection

[`AppDI.shared`](Jesuit/Core/DI/AppDI.swift) is the single Swinject `Container`. It registers **everything**: `NetworkService`, all 7 repositories, every presenter, and the shared state objects (`AuthSession`, `AppTabRouter`, `NavigationService`). Shared services are registered `.inObjectScope(.container)` (singletons).

Two ways to obtain a dependency:

```swift
// 1. Direct resolve (common in views)
@State private var presenter = AppDI.shared.resolver(HomePresenter.self)

// 2. Property wrapper (Core/DI/Injected.swift), resolves from the same container
@Injected private var session: AuthSession
```

Presenters that need a **runtime argument** (an id) are built via a factory method on `AppDI`: `cashReceiptDetailPresenter(id:)`, `transferDetailPresenter(id:)`, `assetDetailPresenter(id:)`.

> **Rule:** register a new dependency in `AppDI.init` **first**, then resolve it.

## Networking

[`NetworkService`](Jesuit/Core/Network/NetworkService.swift) is an **`actor`** conforming to `NetworkServiceProtocol` (`.shared`, 10s/20s timeouts). Three entry points:

| Method | Use |
|---|---|
| `requestDecoded` | JSON body → `T` |
| `request` | → `APIResponse<T>` envelope `{ status, message, code, data }` |
| `requestMultipartDecoded` | File uploads as `attachments_n` parts |

The bearer token is read from [`TokenKeychainActor.shared`](Jesuit/Core/Storage/Keychain/TokenKeychainActor.swift) **per request** and attached when `endpoint.requiresAuth`. A `401` maps to `NetworkError.unauthorized`. The [`Endpoint`](Jesuit/Core/Network/Endpoint.swift) struct carries `baseURL` (defaulting to `AppURLConstants.baseURL`) — repositories pass `baseURL:` explicitly to pick the `core` vs `finance` host.

## Navigation

**Two independent layers** — know which one you're in.

**1. Root flow (auth/launch gating)** — [UIPilot](Jesuit/Core/Vendor/UIPilot) via [`NavigationService`](Jesuit/Presentation/AppNavigation/NavigationService.swift) over the [`AppRoute`](Jesuit/Presentation/AppNavigation/AppRoute.swift) enum (`login / home / register / forgotPassword / resetPassword / …`). [`AppCoordinator`](Jesuit/Presentation/AppNavigation/AppCoordinator.swift) is the root view: it shows `SplashScreen` until `launch()` completes, then hosts UIPilot.

**2. In-tab navigation (plain SwiftUI)** — `MainTabScreen` is a `TabView` bound to [`AppTabRouter.selection`](Jesuit/Presentation/Commons/State/AppTabRouter.swift) (`MainTab`). **Each tab is wrapped in its own `NavigationStack`**, so full-page screens (detail views, create/edit forms, the org switcher, the approval inbox) **push** via `.navigationDestination(isPresented:)` / `.navigationDestination(item:)` — not `.sheet`. This was deliberate: stacked sheet-on-sheet got cramped. Pushed pages use the native back chevron.

Two rules that are easy to get wrong:

- **Tab-bar hiding:** the pushed page must **NOT** own `.toolbar(.hidden, for: .tabBar)` — it gets torn down mid-pop and the tab bar blinks back before the transition finishes. Instead the **tab-root screen** (which never leaves the hierarchy) drives it off its push state: `.toolbar(selected == nil ? .visible : .hidden, for: .tabBar)`.
- **`navigationDestination(item:)` needs a `Hashable` item** — list screens use a small `Identifiable, Hashable` id-wrapper.

**Only leaf pickers stay `.sheet`** (with `.presentationDetents`): `FilterBySheet`, filter/range sheets, `SelectionField`/`SelectionSheet`, line editors, `ShareSheet`, and `ImagePreviewSheet` (a `fullScreenCover`). For a new detail/edit page → **push**. For a new single-select picker → `.sheet` + `FilterBySheet`.

> **Shared detail sheet:** `CashReceiptDetailSheet` renders **both** receipts and disbursements, switched by its `kind: .receipt | .disbursement` parameter — it decides whether to present `CreateReceiptSheet` or `CreateExpenseSheet`. Those two create sheets (and their `EditReceiptLineSheet` / `EditLineSheet` line editors) are near-duplicates: **when you change one, check the other.**

## Shared state

| Object | File | Role |
|---|---|---|
| `AuthSession` | [Commons/State/AuthSession.swift](Jesuit/Presentation/Commons/State/AuthSession.swift) | `user` / `company` / `roles` / `permissions`; `isAuthenticated`, `can(_:)`, `isAdministrator`; `update(with: AuthMe)` / `clear()`. Also defines `enum Permission`. |
| `AppTabRouter` | [Commons/State/AppTabRouter.swift](Jesuit/Presentation/Commons/State/AppTabRouter.swift) | Root tab `selection`; reorderable tab + More-menu order persisted in UserDefaults. Defines `MainTab` (home/kontak/penerimaan/pengeluaran/more) and `MoreMenuItem` (with sections + permission gating). |
| `NavigationService` | [AppNavigation/NavigationService.swift](Jesuit/Presentation/AppNavigation/NavigationService.swift) | Wraps `UIPilot`; `navigate`/`pop`/`replace`/`popTo`. |

All are `@Observable @MainActor` singletons registered in `AppDI`.

## Feature modules

| Feature | Screens | Presenter | Repository | Endpoints |
|---|---|---|---|---|
| Auth | [Auth/](Jesuit/Presentation/Screens/Auth) (Login/Register/Forgot/Reset) | `Login/Register/ForgotPassword/ResetPasswordPresenter` | `AuthRepository` | `/auth/*`, `/users/me` |
| Home dashboard | [Home/](Jesuit/Presentation/Screens/Home) | `HomePresenter` | `DashboardRepository` | 4 `/dashboard/*` widgets (cash flow, cash accounts, balance sheet, daily revenue) |
| Kontak | [Kontak/](Jesuit/Presentation/Screens/Kontak) | `ContactPresenter` | `ContactRepository` | `/contacts`, `/contact-categories` |
| Penerimaan | [Penerimaan/](Jesuit/Presentation/Screens/Penerimaan) | `PenerimaanPresenter`, `CashReceiptDetailPresenter` | `CashReceiptRepository` | `/cash-transactions` (`receipt`) |
| Pengeluaran | [Pengeluaran/](Jesuit/Presentation/Screens/Pengeluaran) | `PengeluaranPresenter`, `CashReceiptDetailPresenter` | `CashReceiptRepository` | `/cash-transactions` (`disbursement`) |
| Transfer Dana | [Transfer/](Jesuit/Presentation/Screens/Transfer) | `TransferPresenter`, `TransferDetailPresenter` | `FundTransferRepository` | `/fund-transfers/*` |
| Aset | [Asset/](Jesuit/Presentation/Screens/Asset) | `AssetPresenter`, `AssetDetailPresenter` | `AssetRepository` | `/assets`, `/asset-categories` |
| Master Akun | [MasterAkun/](Jesuit/Presentation/Screens/MasterAkun) | `MasterAkunPresenter` | `AccountRepository` | `/accounts` |
| Laporan | [Laporan/](Jesuit/Presentation/Screens/Laporan) | `LaporanPresenter`, `BukuBesarPresenter`, `LabaRugiPresenter`, `ArusKasPresenter`, `NeracaPresenter` | Dashboard + Cash receipt repos | see [Reports](#reports-subsystem) |
| Persetujuan | [More/ApprovalInboxScreen](Jesuit/Presentation/Screens/More/ApprovalInboxScreen.swift) | `ApprovalInboxPresenter` | `CashReceiptRepository`, `FundTransferRepository` | `.../{id}/approve` · `.../{id}/reject` |
| Profil / Password | [More/](Jesuit/Presentation/Screens/More) | `EditProfilePresenter`, `ChangePasswordPresenter` | `AuthRepository` | `PUT /users/me`, `PUT /users/me/password` |

## Data layer

Seven repositories in [Data/Repositories](Jesuit/Data/Repositories), each constructed with an injected `NetworkServiceProtocol`; each implements a protocol in [Domain/Protocols](Jesuit/Domain/Protocols):

| Repository | Covers |
|---|---|
| `AuthRepository` | Sign in/up, logout, `fetchMe`, session restore, companies CRUD + switch |
| `ContactRepository` | Paginated contacts + categories (Customer/Vendor), CRUD |
| `CashReceiptRepository` | `/cash-transactions` — both receipts and disbursements, submit/draft, multipart attachments, activity log; branch/account lookups reused elsewhere |
| `FundTransferRepository` | Transfer Dana CRUD + submit/draft lifecycle + activity log |
| `AssetRepository` | Aset CRUD, categories, attachments |
| `DashboardRepository` | Cash-flow card, cash accounts, balance sheet |
| `AccountRepository` | Master Akun (full chart of accounts) CRUD |

Entities live in [Domain/Entities/*Models.swift](Jesuit/Domain/Entities). Note the generic `PaginatedResponse<T>` (with meta/pagination/counts) in [ContactModels.swift](Jesuit/Domain/Entities/ContactModels.swift), used across list endpoints.

## Reports subsystem

The list endpoints **cannot sort/filter server-side**, so reports are computed **client-side**:

- `LaporanPresenter` and the ledger/cash-flow presenters sweep **every page** of receipts + disbursements **once**, cache them, and re-aggregate per selected period entirely offline — a period change never hits the network. Shared sweep + period machinery is in [Presenters/ReportSupport.swift](Jesuit/Presentation/Presenters/ReportSupport.swift) (`TransactionSweep` + `ReportPeriod`).
- **Laba Rugi** is the exception — it hits the dashboard profit-loss endpoint per range.
- The report catalog: More → Laporan → `LaporanIndexScreen`, which pushes Jurnal Umum (`LaporanScreen`), Buku Besar, Laba Rugi, Arus Kas, and presents Neraca as a sheet (it owns its own NavigationStack).
- **Export** via [`ReportExporter`](Jesuit/Core/Utils/ReportExporter.swift) — native `UIGraphicsPDFRenderer` PDF + RFC-4180 CSV (UTF-8 BOM), **no third-party deps**. PDF **pushes** `PDFPreviewPage` (a PDFKit `PDFView` + `ShareLink`); CSV goes through `ShareSheet`. Exports honor the active filters.
- Shared report UI (capsule `ReportChip`, `PeriodMenuChip`, `ReportHeader`, `ReportStateMessage`) lives in `Screens/Laporan/ReportComponents.swift`.

## UI conventions

- **Fonts:** never `.font(.system…)` for text. Use `Text(...).customFont(weight, size)` ([Commons/Extensions/CustomFont.swift](Jesuit/Presentation/Commons/Extensions/CustomFont.swift)) with sizes from the `Typography` enum ([AppTheme.swift](Jesuit/Presentation/Commons/Theme/AppTheme.swift): `display 28 → caption2 11`). Weights `.regular/.medium/.semibold/.bold`. Note Inter's bold styles are `"Semi Bold"` / `"Extra Bold"` (with a space).
- **Colors:** semantic tokens only — `.title`, `.subtitle`, `.accent`, `.income` (green), `.expense` (red), `.background1`, `.textFieldBG` (color sets in `Assets.xcassets/Colors` + `AppTheme`). Don't hardcode hex except via `Color(hex:)`.
- **Currency:** `Double` extensions in [Formatters.swift](Jesuit/Core/Utils/Formatters.swift) — `asRupiah` ("Rp 1.200.000"), `asIDR`, `asSignedRupiah`, `groupedThousands`. `CurrencyField` binds a digits-only string.
- **Grouped forms:** build with `FormCard` primitives ([Components/FormCard.swift](Jesuit/Presentation/Components/FormCard.swift)): `FormPickerRow`, `FormFieldRow`, `FormCurrencyRow`, `FormTextAreaRow`, `FormDateRow`, `FormToggleRow` — Zoho-style label-left/value-right rows. Required-field labels render in `.expense` red.
- **Shared list rows** use `ListMetrics` tokens (in `AppTheme`) across Kontak / Penerimaan / Pengeluaran — changing a token affects all three; override inline to restyle one.
- **Selection sheets:** for single-select, present [`FilterBySheet`](Jesuit/Presentation/Components/FilterBySheet.swift) rather than an inline `Menu`. Convention: an `id == ""` option means **"Semua"** (clear/all).
- **Hot reload:** apply `.hotReloadable()` to a screen's body for Inject live-reload in DEBUG (needs the InjectionIII app; harmless if absent).

## Key gotchas

- **List pagination/filter/search are all client-side.** The cash-transactions and contacts endpoints take only `page`/`limit` (+ `transaction_type`) — no server sort/filter/search. So presenters:
  - track `page`/`totalPages`, expose `loadMore()` + `isLoadingMore`/`canLoadMore` (reusing `AppState.loadmore`), fired from the **last row's `.onAppear`** (not a footer);
  - **dedupe appended pages by id** (the API can repeat a row across page boundaries when timestamps tie);
  - compute filter chips / search over the loaded set, so load-more pages the *unfiltered* data.
  - There is **no list sort UI** — removed because the endpoint can't sort and client re-sorting reshuffled rows during load-more.
- **Receipt vs disbursement duplication** — the shared detail sheet + parallel create/line-edit sheets must be changed in lockstep (see [Navigation](#navigation)).
- **No test target** — there's nothing to `xcodebuild test`. Verify by building + running the flow.
- **Unwired endpoint:** `approval-requests/by-doc` (approval-progress chain) is defined in `AppURLConstants` but has no repository/UI. See [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) for the full wired/partial/stub audit.

## Contributing

- **Commits:** end messages with the `Co-Authored-By` trailer per the harness instructions. Don't commit or push unless asked.
- **Versioning:** bump the build (`xcrun agvtool next-version -all`) before a release; record changes in [CHANGELOG.md](CHANGELOG.md) (written in Indonesian).
- **Deep reference:** [CLAUDE.md](CLAUDE.md) is the most detailed architecture + convention spec — keep it in sync when you change navigation, DI, or report conventions.

## Documentation index

| Doc | What's in it |
|---|---|
| [CLAUDE.md](CLAUDE.md) | Deepest architecture + convention reference (build, DI, navigation, reports, UI). |
| [CHANGELOG.md](CHANGELOG.md) | Release notes ("Catatan Perubahan"), Indonesian. |
| [docs/IMPLEMENTATION_STATUS.md](docs/IMPLEMENTATION_STATUS.md) | Audit of what's wired to the backend (real / partial / stub). |
| [docs/TESTFLIGHT.md](docs/TESTFLIGHT.md) | Archive → export → upload pipeline. |
| [docs/PROGRESS_2026-06-15.md](docs/PROGRESS_2026-06-15.md) | Daily progress log. |
| [BAD_UX_ANALYSIS.md](BAD_UX_ANALYSIS.md) | Verified UX findings (Dynamic Type, validation, required-field cues). |
