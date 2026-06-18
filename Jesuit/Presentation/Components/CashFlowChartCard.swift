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

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            if !series.isEmpty {
                chart
            }
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

    private func panel(
        title: String,
        change: Double,
        trend: String,
        left: (label: String, amount: Double, tint: Color),
        right: (label: String, amount: Double, tint: Color),
        totalLabel: String,
        total: Double
    ) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .customFont(.bold, Typography.headline)
                    .foregroundStyle(.title)
                Spacer()
                trendBadge(change: change, trend: trend)
            }

            HStack(spacing: 12) {
                metric(left.label, left.amount, tint: left.tint)
                metric(right.label, right.amount, tint: right.tint)
            }

            totalRow(totalLabel, total)
        }
    }

    private func metric(_ label: String, _ amount: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .customFont(.regular, Typography.callout)
                .foregroundStyle(.subtitle)
                .lineLimit(1)
            Text(amount.asSignedRupiah)
                .customFont(.semibold, Typography.headline)
                .foregroundStyle(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func totalRow(_ label: String, _ amount: Double) -> some View {
        HStack(spacing: 10) {
            Text(label)
                .customFont(.bold, Typography.body)
                .foregroundStyle(.title)
            Spacer(minLength: 8)
            Text(amount.asSignedRupiah)
                .customFont(.bold, Typography.title2)
                .foregroundStyle(amount < 0 ? Color.expense : .income)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
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
                .customFont(.semibold, Typography.callout)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(tint.opacity(0.14))
        .clipShape(Capsule())
    }
}
