//
//  HomeScreen.swift
//  Jesuit
//
//  Accounting dashboard: org header, summary cards, quick create, cash flow.
//

import SwiftUI

struct HomeScreen: View {
    @Injected private var navigation: NavigationService
    @State private var presenter = AppDI.shared.resolver(HomePresenter.self)
    @State private var showCustomRange = false
    @State private var showOrgSwitcher = false
    @State private var showAllCashAccounts = false
    private let quickColumns = Array(
        repeating: GridItem(.flexible(), spacing: 12),
        count: 3
    )

    var body: some View {
        VStack(spacing: 0) {
            header

            ScrollView {
                VStack(spacing: 28) {
                    summarySection
                    quickCreateSection
                    cashFlowSection
                    cashAccountsSection
                }
                .padding(.horizontal, 16)
                .padding(.top, 20)
                .padding(.bottom, 32)
            }
            .refreshable { await presenter.refresh() }
        }
        .background(Color.background1.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task {
            await presenter.loadCompanies()
            await presenter.loadCashFlow()
            await presenter.loadCashAccounts()
            await presenter.loadBalanceSheet()
        }
        .hotReloadable()
    }

    // MARK: - Header

    private var companySwitcher: some View {
        Button {
            showOrgSwitcher = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "building.2")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.title)
                    .frame(width: 34, height: 34)
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))

                Text(presenter.organization)
                    .customFont(.bold, Typography.title2)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                if presenter.isSwitchingCompany {
                    ProgressView().tint(.title)
                } else {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.title)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(presenter.companies.isEmpty || presenter.isSwitchingCompany)
        .sheet(isPresented: $showOrgSwitcher) {
            OrganizationSwitcherSheet(
                presenter: presenter,
                onSelect: { await presenter.switchCompany(to: $0) }
            )
        }
    }

    private var header: some View {
        HStack(spacing: 12) {
            companySwitcher

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Summary (Neraca / balance sheet)

    private var summarySection: some View {
        balanceSheetCard
    }

    private var balanceSheetCard: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                Text("Neraca")
                    .customFont(.semibold, Typography.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(balanceSheetAsOf)
                    .customFont(.regular, Typography.subhead)
                    .foregroundStyle(Color.white.opacity(0.7))
            }

            VStack(spacing: 0) {
                balanceSheetRow(
                    title: "Harta",
                    amount: presenter.balanceSheet?.assets ?? 0,
                    systemImage: "building.columns.fill"
                )
                rowDivider
                balanceSheetRow(
                    title: "Kewajiban",
                    amount: presenter.balanceSheet?.liabilities ?? 0,
                    systemImage: "creditcard.fill"
                )
                rowDivider
                balanceSheetRow(
                    title: "Modal",
                    amount: presenter.balanceSheet?.equity ?? 0,
                    systemImage: "chart.pie.fill"
                )
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.27, blue: 0.49),
                         Color(red: 0.09, green: 0.20, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(alignment: .topTrailing) {
            if presenter.isBalanceSheetLoading {
                ProgressView()
                    .tint(.white)
                    .padding(18)
            }
        }
    }

    /// "Per 17 Juni 2026" — the snapshot date, localised to Indonesian.
    private var balanceSheetAsOf: String {
        let date = presenter.balanceSheet?.asOfDate ?? .now
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d MMMM yyyy"
        return "Per \(f.string(from: date))"
    }

    private var rowDivider: some View {
        Divider()
            .overlay(Color.white.opacity(0.14))
            .padding(.vertical, 14)
    }

    /// One balance-sheet line: icon + label on the left, amount on the right —
    /// full row width so the number stays large and readable.
    private func balanceSheetRow(title: String, amount: Double, systemImage: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.7))
                .frame(width: 22)
            Text(title)
                .customFont(.medium, Typography.callout)
                .foregroundStyle(Color.white.opacity(0.85))
            Spacer(minLength: 12)
            Text(amount.asIDR)
                .customFont(.bold, Typography.headline)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - Quick Create

    private var quickCreateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.subtitle)
                Text("Buat Cepat")
                    .customFont(.semibold, Typography.title2)
                    .foregroundStyle(.title)
            }

            LazyVGrid(columns: quickColumns, spacing: 12) {
                ForEach(presenter.quickActions) { action in
                    quickTile(action)
                }
            }
        }
    }

    private func quickTile(_ action: QuickAction) -> some View {
        Button {
            presenter.selectTab(action.destination)
        } label: {
            VStack(spacing: 10) {
                Image(systemName: action.systemImage)
                    .font(.system(size: 24))
                    .foregroundStyle(tintColor(action.tint))
                    .frame(maxWidth: .infinity)
                    .frame(height: 64)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                Text(action.title)
                    .customFont(.medium, Typography.body)
                    .foregroundStyle(.title)
            }
        }
        .buttonStyle(.plain)
    }

    private func tintColor(_ tint: QuickActionTint) -> Color {
        switch tint {
        case .accent: .accentColor
        case .income: .income
        case .expense: .expense
        case .neutral: .title
        }
    }

    // MARK: - Project Summary

    private var projectSummarySection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 10) {
                Image(systemName: "rectangle.stack")
                    .font(.system(size: 16))
                    .foregroundStyle(.subtitle)
                Text("Project Summary")
                    .customFont(.semibold, Typography.title2)
                    .foregroundStyle(.title)
            }

            ProjectSummaryCard(
                timerDisplay: presenter.timerDisplay,
                isRunning: presenter.isTimerRunning,
                unbilledHours: presenter.unbilledHours,
                unbilledExpenses: presenter.unbilledExpenses,
                onToggleTimer: { presenter.toggleTimer() },
                onLogTime: { presenter.logTime() }
            )
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    // MARK: - Cash & Bank accounts

    private var cashAccountsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            if presenter.isCashAccountsLoading {
                ProgressView()
                    .tint(.accent)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else if presenter.cashAccounts.isEmpty {
                cashAccountsEmptyState
            } else {
                CashAccountsCard(
                    total: presenter.cashAccountsTotal,
                    accounts: presenter.cashAccounts,
                    onShowAll: { showAllCashAccounts = true }
                )
            }
        }
        .sheet(isPresented: $showAllCashAccounts) {
            CashAccountsListSheet(
                total: presenter.cashAccountsTotal,
                accounts: presenter.cashAccounts
            )
        }
    }

    private var cashAccountsEmptyState: some View {
        Text("Belum ada rekening kas atau bank.")
            .customFont(.regular, Typography.body)
            .foregroundStyle(.subtitle)
            .frame(maxWidth: .infinity, minHeight: 120)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    // MARK: - Cash Flow

    private var cashFlowSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 16))
                        .foregroundStyle(.subtitle)
                    Text("Arus Kas")
                        .customFont(.semibold, Typography.title2)
                        .foregroundStyle(.title)
                }
                Spacer()
                periodMenu
            }

            if presenter.hasCustomRange {
                customRangeLabel
            } else {
                periodStepper
            }

            if presenter.isCashFlowLoading {
                ProgressView()
                    .tint(.accent)
                    .frame(maxWidth: .infinity, minHeight: 150)
            } else {
                CashFlowChartCard(
                    series: presenter.cashFlowSeries,
                    granularity: presenter.cashFlowGranularity,
                    profitLoss: presenter.profitLoss,
                    cashMovement: presenter.cashMovement
                )
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .padding(.horizontal, -16)
    }

    private var periodStepper: some View {
        HStack {
            stepperButton(systemImage: "chevron.left") { presenter.stepPeriod(by: -1) }
            Spacer()
            Text(presenter.cashFlowSteppedLabel)
                .customFont(.semibold, Typography.headline)
                .foregroundStyle(.title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            stepperButton(systemImage: "chevron.right") { presenter.stepPeriod(by: 1) }
        }
        .padding(.horizontal, 4)
    }

    private func stepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.subtitle)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
    }

    private var periodMenu: some View {
        Menu {
            ForEach(CashFlowPeriod.allCases) { period in
                Button {
                    presenter.cashFlowPeriod = period
                } label: {
                    if !presenter.hasCustomRange && presenter.cashFlowPeriod == period {
                        Label(period.rawValue, systemImage: "checkmark")
                    } else {
                        Text(period.rawValue)
                    }
                }
            }
            Divider()
            Button {
                showCustomRange = true
            } label: {
                if presenter.hasCustomRange {
                    Label("Rentang Khusus…", systemImage: "checkmark")
                } else {
                    Text("Rentang Khusus…")
                }
            }
        } label: {
            HStack(spacing: 6) {
                Text(presenter.cashFlowRangeLabel)
                    .customFont(.medium, Typography.body)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.subtitle)
            }
        }
        .sheet(isPresented: $showCustomRange) {
            CashFlowRangeSheet(
                initialRange: presenter.cashFlowSummaryRange,
                onApply: { start, end in presenter.applyCustomRange(start: start, end: end) }
            )
        }
    }

    /// Centered label for an active custom range (replaces the stepper).
    private var customRangeLabel: some View {
        Text(presenter.cashFlowSteppedLabel)
            .customFont(.semibold, Typography.headline)
            .foregroundStyle(.title)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }
}
