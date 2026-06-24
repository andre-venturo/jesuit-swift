//
//  HomePresenter.swift
//  Jesuit
//
//  Presenter for the dashboard home screen.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class HomePresenter {
    private let authRepository: AuthRepositoryProtocol
    private let dashboardRepository: DashboardRepositoryProtocol
    private let session: AuthSession
    private let tabRouter: AppTabRouter

    init(
        authRepository: AuthRepositoryProtocol,
        dashboardRepository: DashboardRepositoryProtocol,
        session: AuthSession,
        tabRouter: AppTabRouter
    ) {
        self.authRepository = authRepository
        self.dashboardRepository = dashboardRepository
        self.session = session
        self.tabRouter = tabRouter
    }

    /// Switches the root tab bar (used by Quick Create tiles).
    func selectTab(_ tab: MainTab) {
        tabRouter.select(tab)
    }

    /// Live, session-backed display values (falls back to placeholders when signed out).
    var userName: String { session.isAuthenticated ? session.displayName : "Andre" }
    var organization: String { session.isAuthenticated ? session.organization : "Venturo" }

    /// Revokes the refresh token, clears local credentials and the session.
    func logout() async {
        try? await authRepository.logout()
        session.clear()
    }

    /// Pull-to-refresh: reloads the dashboard's data in parallel (profile, cash
    /// flow and cash accounts).
    func refresh() async {
        async let profile: Void = refreshProfile()
        async let cashFlow: Void = loadCashFlow()
        async let cashAccounts: Void = loadCashAccounts()
        async let balanceSheet: Void = loadBalanceSheet()
        _ = await (profile, cashFlow, cashAccounts, balanceSheet)
    }

    /// Loads the latest profile from `/auth/me` (e.g. on dashboard appear).
    func refreshProfile() async {
        if let me = try? await authRepository.fetchMe() {
            session.update(with: me)
        }
    }

    // MARK: - Company switcher

    /// Companies the user can switch between (holding + subsidiaries), shown in
    /// the header switcher.
    private(set) var companies: [CompanyDTO] = []

    /// The company currently being switched to (drives a per-row spinner / lock);
    /// `nil` when idle.
    private(set) var switchingCompanyId: String?

    var isSwitchingCompany: Bool { switchingCompanyId != nil }

    /// Id of the active company from the session, for the switcher's checkmark.
    var activeCompanyId: String? { session.company?.id }

    /// Loads the switchable companies (no-op on failure — the switcher just
    /// stays empty).
    func loadCompanies() async {
        if let list = try? await authRepository.fetchCompanies() {
            companies = list
        }
    }

    /// Switches the active company, refreshes the session and reloads the
    /// dashboard data for the new company. Returns `true` on success.
    @discardableResult
    func switchCompany(to companyId: String) async -> Bool {
        guard companyId != activeCompanyId, switchingCompanyId == nil else { return false }
        switchingCompanyId = companyId
        switchError = nil
        defer { switchingCompanyId = nil }
        do {
            let me = try await authRepository.switchCompany(to: companyId)
            session.update(with: me)
            await loadCashFlow()
            await loadCashAccounts()
            await loadBalanceSheet()
            return true
        } catch {
            switchError = LoginPresenter.message(for: error)
            return false
        }
    }

    /// Set when a company switch fails, so the switcher can show an alert.
    var switchError: String?

    // MARK: - Create / edit company

    /// Editable form backing the "Perusahaan Baru" create/edit sheet.
    @Observable
    @MainActor
    final class CreateCompanyForm {
        var name = ""
        var type: CompanyType = .holding
        /// Parent holding for a subsidiary; ignored when `type == .holding`.
        var parentId = ""
        var errorMessage: String?

        /// Non-nil when editing an existing company (PUT instead of create).
        var editId: String?

        /// Holdings the user owns, offered as parents for a subsidiary.
        var parentOptions: [CompanyDTO] = []

        var isEditing: Bool { editId != nil }

        /// Display name of the picked parent for the menu label.
        var parentName: String {
            parentOptions.first { $0.id == parentId }?.name ?? "Pilih induk"
        }

        var isValid: Bool {
            let hasName = !name.trimmingCharacters(in: .whitespaces).isEmpty
            switch type {
            case .holding: return hasName
            case .subsidiary: return hasName && !parentId.isEmpty
            }
        }

        func reset(parents: [CompanyDTO]) {
            name = ""; type = .holding; parentId = ""; errorMessage = nil
            editId = nil
            parentOptions = parents
        }

        /// Resets to a new subsidiary with `parent` preselected. The parent is
        /// guaranteed present in the options even if it isn't a holding.
        func resetAsSubsidiary(parent: CompanyDTO, parents: [CompanyDTO]) {
            name = ""; type = .subsidiary; parentId = parent.id; errorMessage = nil
            editId = nil
            parentOptions = parents.contains { $0.id == parent.id } ? parents : [parent] + parents
        }

        /// Seeds the form from an existing company for editing. A company can't
        /// be its own parent, so it's excluded from the holding options.
        func seed(from company: CompanyDTO, parents: [CompanyDTO]) {
            editId = company.id
            name = company.name
            type = company.isHolding ? .holding : .subsidiary
            parentId = company.parentId ?? ""
            errorMessage = nil
            parentOptions = parents.filter { $0.id != company.id }
        }

        func makeRequest() -> CreateCompanyRequest {
            CreateCompanyRequest(
                name: name.trimmingCharacters(in: .whitespaces),
                type: type.rawValue,
                parentId: type == .subsidiary ? parentId : nil
            )
        }
    }

    let companyForm = CreateCompanyForm()
    private(set) var isCreatingCompany = false
    /// Id of the company currently being deleted (drives a per-row spinner).
    private(set) var deletingCompanyId: String?

    /// Holdings the user owns, offered as parents for a subsidiary.
    private var holdingOptions: [CompanyDTO] { companies.filter { $0.isHolding } }

    /// Resets the form for a brand-new company, seeding holdings as parents.
    func startCreateCompany() {
        companyForm.reset(parents: holdingOptions)
    }

    /// Resets the form for a new subsidiary preset under `parent` (the menu's
    /// "Anak Perusahaan" action).
    func startCreateSubsidiary(under parent: CompanyDTO) {
        companyForm.resetAsSubsidiary(parent: parent, parents: holdingOptions)
    }

    /// Seeds the form from an existing company for editing (PUT on save).
    func startEditCompany(_ company: CompanyDTO) {
        companyForm.seed(from: company, parents: holdingOptions)
    }

    /// Creates or updates a company (PUT when the form is in edit mode), reloads
    /// the switcher list, and returns `true` on success.
    @discardableResult
    func createCompany() async -> Bool {
        guard companyForm.isValid, !isCreatingCompany else { return false }
        isCreatingCompany = true
        companyForm.errorMessage = nil
        defer { isCreatingCompany = false }
        do {
            if let editId = companyForm.editId {
                _ = try await authRepository.updateCompany(id: editId, request: companyForm.makeRequest())
            } else {
                _ = try await authRepository.createCompany(companyForm.makeRequest())
            }
            await loadCompanies()
            await refreshProfile()
            return true
        } catch let error as NetworkError {
            // Prefer the backend's message; fall back to a generic Indonesian copy.
            if case let .serverError(_, message?) = error, !message.isEmpty {
                companyForm.errorMessage = message
            } else {
                companyForm.errorMessage = "Gagal menyimpan perusahaan."
            }
            return false
        } catch {
            companyForm.errorMessage = "Gagal menyimpan perusahaan."
            return false
        }
    }

    /// Deletes a company and reloads the switcher list. Returns `true` on
    /// success. The active company can't be deleted (guarded by the caller).
    @discardableResult
    func deleteCompany(id: String) async -> Bool {
        guard deletingCompanyId == nil else { return false }
        deletingCompanyId = id
        defer { deletingCompanyId = nil }
        do {
            try await authRepository.deleteCompany(id: id)
            await loadCompanies()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Dashboard summary (Neraca / balance sheet)

    private(set) var balanceSheetState: AppState<BalanceSheetSummary> = .idle

    var isBalanceSheetLoading: Bool {
        if case .loading = balanceSheetState { return true }
        return false
    }

    var balanceSheet: BalanceSheetSummary? {
        if case .success(let data) = balanceSheetState { return data }
        return nil
    }

    /// Loads the Neraca card (assets / liabilities / equity) as of today.
    func loadBalanceSheet() async {
        balanceSheetState = .loading
        do {
            let data = try await dashboardRepository.fetchBalanceSheet(asOf: .now)
            balanceSheetState = .success(data)
        } catch {
            balanceSheetState = .error(error)
        }
    }

    /// Shortcuts to the app's real, creatable features (the tab bar destinations).
    let quickActions: [QuickAction] = [
        QuickAction(title: "Penerimaan", systemImage: "arrow.down.circle.fill", tint: .income, destination: .penerimaan),
        QuickAction(title: "Pengeluaran", systemImage: "arrow.up.circle.fill", tint: .expense, destination: .pengeluaran),
        QuickAction(title: "Kontak", systemImage: "person.2.fill", tint: .accent, destination: .kontak)
    ]

    let kpis: [KPI] = [
        KPI(title: "Total Receivables", amount: 48250, deltaPercent: 12.4, systemImage: "arrow.down.left.circle.fill"),
        KPI(title: "Total Payables", amount: 18940, deltaPercent: -4.1, systemImage: "arrow.up.right.circle.fill"),
        KPI(title: "Cash in Hand", amount: 92310, deltaPercent: 8.7, systemImage: "banknote.fill"),
        KPI(title: "Net Income", amount: 29310, deltaPercent: 15.2, systemImage: "chart.line.uptrend.xyaxis")
    ]

    let cashflow: [CashflowPoint] = [
        .init(month: "Jan", income: 32000, expense: 21000),
        .init(month: "Feb", income: 28000, expense: 19500),
        .init(month: "Mar", income: 41000, expense: 24000),
        .init(month: "Apr", income: 38500, expense: 22000),
        .init(month: "May", income: 46000, expense: 27500),
        .init(month: "Jun", income: 52000, expense: 26000)
    ]

    // MARK: - Project Summary

    /// Elapsed seconds on the running project timer.
    private(set) var timerSeconds: Int = 0
    private(set) var isTimerRunning = false
    private var timerTask: Task<Void, Never>?

    /// `HH:MM:SS` for the timer display.
    var timerDisplay: String {
        let h = timerSeconds / 3600
        let m = (timerSeconds % 3600) / 60
        let s = timerSeconds % 60
        return String(format: "%02d:%02d:%02d", h, m, s)
    }

    /// Seeded project metrics (swap for a repository fetch when the endpoint lands).
    var unbilledHours: String = "0:00"
    var unbilledExpenses: Double = 0

    func toggleTimer() {
        isTimerRunning ? stopTimer() : startTimer()
    }

    func startTimer() {
        guard !isTimerRunning else { return }
        isTimerRunning = true
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                guard let self, self.isTimerRunning else { break }
                self.timerSeconds += 1
            }
        }
    }

    func stopTimer() {
        isTimerRunning = false
        timerTask?.cancel()
        timerTask = nil
    }

    func logTime() {
        // Hook up the manual time-entry flow when the form lands.
        stopTimer()
        timerSeconds = 0
    }

    // MARK: - Cash & Bank accounts (Rekening Kas & Bank)

    private(set) var cashAccountsState: AppState<CashAccounts> = .idle

    var isCashAccountsLoading: Bool {
        if case .loading = cashAccountsState { return true }
        return false
    }

    var cashAccounts: [CashAccount] {
        if case .success(let data) = cashAccountsState { return data.accounts }
        return []
    }

    var cashAccountsTotal: Double {
        if case .success(let data) = cashAccountsState { return data.totalBalance }
        return 0
    }

    /// Loads the cash & bank accounts card (no-op visual on failure → empty).
    func loadCashAccounts() async {
        cashAccountsState = .loading
        do {
            let data = try await dashboardRepository.fetchCashAccounts()
            cashAccountsState = data.accounts.isEmpty ? .empty : .success(data)
        } catch {
            cashAccountsState = .error(error)
        }
    }

    // MARK: - Cash Flow card

    /// Selected preset for the dashboard Cash Flow card. Changing it clears any
    /// custom range, resets the stepper offset and reloads.
    var cashFlowPeriod: CashFlowPeriod = .bulanIni {
        didSet {
            guard cashFlowPeriod != oldValue else { return }
            customRange = nil
            periodOffset = 0
            Task { await loadCashFlow() }
        }
    }

    /// How many units (days/weeks/months/years) the prev/next stepper has moved
    /// from the preset's default position. Negative = past, positive = future.
    private(set) var periodOffset = 0

    /// User-picked `[start, end]` that overrides `cashFlowPeriod` when set.
    private(set) var customRange: (start: Date, end: Date)?

    var hasCustomRange: Bool { customRange != nil }

    /// The active range driving the card: the custom range if set, else the
    /// preset shifted by `periodOffset`.
    private var effectiveRange: (start: Date, end: Date) {
        customRange ?? cashFlowPeriod.dateRange(offset: periodOffset)
    }

    /// Current active range, for seeding the custom-range picker.
    var cashFlowSummaryRange: (start: Date, end: Date) { effectiveRange }

    /// Center label for the stepper / custom range, e.g. `Januari 2026` or
    /// `1 Jan – 20 Jan 2026`.
    var cashFlowSteppedLabel: String {
        if let range = customRange {
            let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "d MMM"
            let endF = DateFormatter(); endF.locale = Locale(identifier: "id_ID"); endF.dateFormat = "d MMM yyyy"
            return "\(f.string(from: range.start)) – \(endF.string(from: range.end))"
        }
        return cashFlowPeriod.steppedLabel(offset: periodOffset)
    }

    /// Dropdown label: the preset name, or "Custom" when a custom range is set.
    var cashFlowRangeLabel: String { hasCustomRange ? "Custom" : cashFlowPeriod.rawValue }

    /// Steps the active range one unit back / forward and reloads. No-op while a
    /// custom range is active (the stepper is hidden then).
    func stepPeriod(by delta: Int) {
        guard !hasCustomRange else { return }
        periodOffset += delta
        Task { await loadCashFlow() }
    }

    /// Applies a custom date range (normalising order) and reloads.
    func applyCustomRange(start: Date, end: Date) {
        customRange = start <= end ? (start, end) : (end, start)
        Task { await loadCashFlow() }
    }

    private(set) var cashFlowState: AppState<DashboardCashFlow> = .idle

    var isCashFlowLoading: Bool {
        if case .loading = cashFlowState { return true }
        return false
    }

    /// Cumulative cash-balance line for the selected period (empty until loaded).
    var cashFlowSeries: [CashFlowSeriesPoint] {
        if case .success(let data) = cashFlowState { return data.series }
        return []
    }

    /// Bucket size of the loaded series, for the chart's x-axis date format.
    var cashFlowGranularity: CashFlowGranularity {
        if case .success(let data) = cashFlowState { return data.granularity }
        return .daily
    }

    /// Laba Rugi (profit/loss) panel for the selected period.
    var profitLoss: ProfitLossSummary? {
        if case .success(let data) = cashFlowState { return data.profitLoss }
        return nil
    }

    /// Arus Kas (cash movement) panel for the selected period.
    var cashMovement: CashFlowMovement? {
        if case .success(let data) = cashFlowState { return data.cashFlow }
        return nil
    }

    /// Loads the Cash Flow card for the active range. Stays `.success` even with
    /// an empty chart so the summary panels still render.
    func loadCashFlow() async {
        cashFlowState = .loading
        let range = effectiveRange
        do {
            let data = try await dashboardRepository.fetchCashFlow(
                startDate: range.start, endDate: range.end
            )
            cashFlowState = .success(data)
        } catch {
            cashFlowState = .error(error)
        }
    }

    let invoices: [Invoice] = [
        .init(number: "INV-1042", customer: "Globex Corp", amount: 12500, dueDate: .now.addingTimeInterval(86400 * 5), status: .pending),
        .init(number: "INV-1041", customer: "Initech", amount: 8400, dueDate: .now.addingTimeInterval(-86400 * 2), status: .overdue),
        .init(number: "INV-1040", customer: "Stark Industries", amount: 21000, dueDate: .now.addingTimeInterval(-86400 * 10), status: .paid),
        .init(number: "INV-1039", customer: "Wayne Enterprises", amount: 6350, dueDate: .now.addingTimeInterval(86400 * 12), status: .draft)
    ]

    let expenses: [Expense] = [
        .init(category: "Software", vendor: "Figma", amount: 144, date: .now.addingTimeInterval(-86400 * 1), systemImage: "macwindow"),
        .init(category: "Travel", vendor: "Delta Airlines", amount: 820, date: .now.addingTimeInterval(-86400 * 3), systemImage: "airplane"),
        .init(category: "Office", vendor: "WeWork", amount: 1200, date: .now.addingTimeInterval(-86400 * 6), systemImage: "building.2"),
        .init(category: "Meals", vendor: "Blue Bottle", amount: 38, date: .now.addingTimeInterval(-86400 * 7), systemImage: "cup.and.saucer")
    ]
}
