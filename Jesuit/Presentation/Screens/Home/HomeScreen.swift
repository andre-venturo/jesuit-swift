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
        }
        .hotReloadable()
    }

    // MARK: - Header

    private var companySwitcher: some View {
        Button {
            showOrgSwitcher = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "building.2")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.title)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))

                Text(presenter.organization)
                    .customFont(.bold, 22)
                    .foregroundStyle(.title)
                    .lineLimit(1)

                if presenter.isSwitchingCompany {
                    ProgressView().tint(.title)
                } else {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 14, weight: .semibold))
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

            Button(action: {}) {
                Image(systemName: "bell")
                    .font(.system(size: 18, weight: .regular))
                    .foregroundStyle(.title)
                    .frame(width: 44, height: 44)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 16)
    }

    // MARK: - Summary

    private var summarySection: some View {
        HStack(alignment: .top, spacing: 12) {
            balanceCard
            VStack(spacing: 12) {
                overdueCard(
                    count: presenter.overdueInvoices,
                    title: "Overdue Invoices",
                    tint: .expense
                )
                overdueCard(
                    count: presenter.overdueBills,
                    title: "Overdue Bills",
                    tint: .orange
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var balanceCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            balanceRow(title: "Total Receivables", amount: presenter.totalReceivables)
            Spacer(minLength: 28)
            balanceRow(title: "Total Payables", amount: presenter.totalPayables)
        }
        .padding(18)
        .frame(maxWidth: .infinity, minHeight: 220, alignment: .topLeading)
        .background(
            LinearGradient(
                colors: [Color(red: 0.13, green: 0.27, blue: 0.49),
                         Color(red: 0.09, green: 0.20, blue: 0.38)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func balanceRow(title: String, amount: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .customFont(.regular, 16)
                .foregroundStyle(Color.white.opacity(0.7))
            HStack(spacing: 6) {
                Text(amount.asIDR)
                    .customFont(.bold, 24)
                    .foregroundStyle(.white)
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white.opacity(0.7))
            }
        }
    }

    private func overdueCard(count: Int, title: String, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                Text("\(count)")
                    .customFont(.bold, 24)
                    .foregroundStyle(.title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.subtitle)
            }
            Text(title)
                .customFont(.regular, 16)
                .foregroundStyle(.subtitle)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(tint.opacity(0.14))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    // MARK: - Quick Create

    private var quickCreateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.subtitle)
                Text("Quick Create")
                    .customFont(.semibold, 20)
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
                    .customFont(.medium, 15)
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
                    .customFont(.semibold, 20)
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
                    accounts: presenter.cashAccounts
                )
            }
        }
        .padding(.horizontal, -16)
    }

    private var cashAccountsEmptyState: some View {
        Text("No cash or bank accounts to show.")
            .customFont(.regular, 16)
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
                    Text("Cash Flow")
                        .customFont(.semibold, 20)
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
                .customFont(.semibold, 17)
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
                    .customFont(.medium, 16)
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
            .customFont(.semibold, 17)
            .foregroundStyle(.title)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }
}
