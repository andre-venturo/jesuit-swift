//
//  CashFlowChartCard.swift
//  Jesuit
//
//  Dashboard "Cash Flow" card: a cumulative cash-balance line chart over the
//  selected period, followed by minimal Laba Rugi (profit/loss) and Arus Kas
//  (cash movement) summary panels with trend badges.
//

import SwiftUI
import Charts

struct CashFlowChartCard: View {
    let series: [CashFlowSeriesPoint]
    let granularity: CashFlowGranularity
    let profitLoss: ProfitLossSummary?
    let cashMovement: CashFlowMovement?

    /// Which summary panel the segmented toggle shows.
    private enum SummaryTab: String, CaseIterable, Identifiable {
        case labaRugi = "Laba Rugi"
        case arusKas  = "Arus Kas"
        var id: String { rawValue }
    }

    @State private var selectedTab: SummaryTab = .labaRugi

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !series.isEmpty {
                chart
            }
            if profitLoss != nil || cashMovement != nil {
                summaryToggle
                summaryContent
            }
        }
    }

    // MARK: - Summary toggle + content

    /// Segmented pill control switching between the Laba Rugi and Arus Kas panels.
    private var summaryToggle: some View {
        HStack(spacing: 4) {
            ForEach(SummaryTab.allCases) { tab in
                let isActive = selectedTab == tab
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { selectedTab = tab }
                } label: {
                    Text(tab.rawValue)
                        .customFont(.semibold, Typography.subhead)
                        .foregroundStyle(isActive ? .title : .subtitle)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(isActive ? Color.white.opacity(0.12) : .clear)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color.white.opacity(0.05))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var summaryContent: some View {
        switch selectedTab {
        case .labaRugi:
            if let profitLoss {
                panel(
                    title: "Laba Rugi",
                    change: profitLoss.changePercentage,
                    trend: profitLoss.trend,
                    left: ("Pendapatan", profitLoss.revenue, .income),
                    right: ("Beban", -abs(profitLoss.expenses), .expense),
                    totalLabel: "Laba Periode Ini",
                    total: profitLoss.profit
                )
            }
        case .arusKas:
            if let cashMovement {
                panel(
                    title: "Arus Kas",
                    change: cashMovement.changePercentage,
                    trend: cashMovement.trend,
                    left: ("Jurnal Penerimaan", cashMovement.receipt, .income),
                    right: ("Jurnal Pengeluaran", -abs(cashMovement.disbursement), .expense),
                    totalLabel: "Kenaikan Kas",
                    total: cashMovement.cashIncrease
                )
            }
        }
    }

    // MARK: - Chart

    private var chart: some View {
        Chart {
            ForEach(series) { point in
                AreaMark(
                    x: .value("Period", point.date),
                    y: .value("Balance", point.balance)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.accentColor.opacity(0.25), Color.accentColor.opacity(0.02)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                LineMark(
                    x: .value("Period", point.date),
                    y: .value("Balance", point.balance)
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.accentColor)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading) { value in
                AxisGridLine().foregroundStyle(Color.subtitle.opacity(0.15))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(v.asCompactSigned)
                            .customFont(.regular, Typography.caption2)
                            .foregroundStyle(.subtitle)
                    }
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 5)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: granularity == .monthly
                            ? .dateTime.month(.abbreviated)
                            : .dateTime.day().month(.abbreviated))
                            .customFont(.regular, Typography.caption2)
                            .foregroundStyle(.subtitle)
                            .multilineTextAlignment(.center)
                    }
                }
            }
        }
        .environment(\.locale, Locale(identifier: "id_ID"))
        .frame(height: 200)
    }

    // MARK: - Summary panel (Laba Rugi / Arus Kas)

    /// Mobile-first summary: lead with the outcome (profit / cash increase) as a
    /// hero number, then list the two contributing amounts as simple, full-width
    /// lines with a colored dot. Vertical and scannable — no side-by-side tiles.
    private func panel(
        title: String,
        change: Double,
        trend: String,
        left: (label: String, amount: Double, tint: Color),
        right: (label: String, amount: Double, tint: Color),
        totalLabel: String,
        total: Double
    ) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Hero: the headline result + trend
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(total.asSignedRupiah)
                        .customFont(.bold, Typography.title)
                        .foregroundStyle(total < 0 ? Color.expense : .income)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text(totalLabel)
                        .customFont(.regular, Typography.subhead)
                        .foregroundStyle(.subtitle)
                }
                Spacer(minLength: 8)
                trendBadge(change: change, trend: trend)
            }

            // Breakdown
            VStack(spacing: 10) {
                breakdownLine(left.label, left.amount, tint: left.tint)
                breakdownLine(right.label, right.amount, tint: right.tint)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    /// A dot · label ────── amount line.
    private func breakdownLine(_ label: String, _ amount: Double, tint: Color) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(label)
                .customFont(.regular, Typography.callout)
                .foregroundStyle(.subtitle)
            Spacer(minLength: 8)
            Text(amount.asSignedRupiah)
                .customFont(.medium, Typography.callout)
                .foregroundStyle(.title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    private func trendBadge(change: Double, trend: String) -> some View {
        let isUp = trend.lowercased() == "up"
        let isDown = trend.lowercased() == "down"
        let tint: Color = isUp ? .income : (isDown ? .expense : .subtitle)
        let glyph = isUp ? "arrow.up" : (isDown ? "arrow.down" : "minus")
        return HStack(spacing: 4) {
            Image(systemName: glyph)
                .font(.system(size: 11, weight: .bold))
            Text("\(Int(change.rounded()))%")
                .customFont(.semibold, Typography.subhead)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14))
        .clipShape(Capsule())
    }
}
