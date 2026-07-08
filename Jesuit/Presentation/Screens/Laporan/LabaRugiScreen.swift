//
//  LabaRugiScreen.swift
//  Jesuit
//
//  Laba Rugi (profit & loss statement) for the selected period: Pendapatan,
//  Beban and Laba (Rugi) Bersih from the dashboard profit-loss endpoint,
//  in the Neraca statement style. Pushed from LaporanIndexScreen.
//

import SwiftUI

struct LabaRugiScreen: View {
    @Injected private var session: AuthSession
    @State private var presenter = AppDI.shared.resolver(LabaRugiPresenter.self)
    @State private var showCustomRange = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PeriodMenuChip(period: presenter.period, showCustomRange: $showCustomRange)
                if presenter.isLoading {
                    ProgressView().tint(.accent)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = presenter.errorMessage {
                    ReportStateMessage(text: error, systemImage: "exclamationmark.triangle")
                } else if let summary = presenter.summary {
                    ReportHeader(
                        organization: session.organization,
                        title: "Laba Rugi",
                        subtitle: reportRangeText(presenter.period.range)
                    )
                    statementCard(summary)
                } else {
                    ReportStateMessage(text: "Tidak ada data pada periode ini.", systemImage: "tray")
                }
            }
            .padding(16)
        }
        .refreshable { await presenter.load(forceReload: true) }
        .background(Color.background1.ignoresSafeArea())
        .navigationTitle("Laba Rugi")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCustomRange) {
            CashFlowRangeSheet(
                initialRange: presenter.period.range,
                onApply: { start, end in presenter.period.applyCustomRange(start: start, end: end) }
            )
        }
        .task { await presenter.load() }
        .hotReloadable()
    }

    // MARK: - Statement

    private func statementCard(_ summary: ProfitLossSummary) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                line("Pendapatan", summary.revenue)
                Divider()
                line("Beban", summary.expenses)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text(summary.profit < 0 ? "Rugi Bersih" : "Laba Bersih")
                        .customFont(.bold, Typography.body)
                        .foregroundStyle(.title)
                    Spacer(minLength: 8)
                    Text(summary.profit.asAccounting)
                        .customFont(.bold, Typography.body)
                        .foregroundStyle(summary.profit < 0 ? .expense : .income)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.title.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.top, 8)

                if summary.changePercentage != 0 {
                    changeLine(summary)
                }
            }
        }
    }

    private func line(_ label: String, _ amount: Double) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .customFont(.regular, Typography.body)
                .foregroundStyle(.title)
            Spacer(minLength: 8)
            Text(amount.asAccounting)
                .customFont(.regular, Typography.body)
                .foregroundStyle(.title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 10)
    }

    /// "▲ 12,5% dibanding periode sebelumnya" under the grand total.
    private func changeLine(_ summary: ProfitLossSummary) -> some View {
        let up = summary.trend == "up"
        return HStack(spacing: 6) {
            Image(systemName: up ? "arrow.up.right" : "arrow.down.right")
                .font(.system(size: 11, weight: .semibold))
            Text("\(abs(summary.changePercentage), specifier: "%.1f")% dibanding periode sebelumnya")
                .customFont(.regular, ListMetrics.metaSize)
        }
        .foregroundStyle(up ? Color.income : .expense)
        .padding(.top, 10)
    }
}
