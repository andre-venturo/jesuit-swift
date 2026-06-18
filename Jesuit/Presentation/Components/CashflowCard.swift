//
//  CashflowCard.swift
//  Jesuit
//
//  Income vs expense bar chart for the last 6 months.
//

import SwiftUI
import Charts

struct CashflowCard: View {
    let points: [CashflowPoint]

    var body: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Cash Flow")
                            .customFont(.semibold, Typography.headline)
                            .foregroundStyle(.title)
                        Text("Last 6 months")
                            .customFont(.regular, Typography.subhead)
                            .foregroundStyle(.subtitle)
                    }
                    Spacer()
                    HStack(spacing: 14) {
                        LegendDot(color: .income, label: "Income")
                        LegendDot(color: .expense, label: "Expense")
                    }
                }

                Chart {
                    ForEach(points) { point in
                        BarMark(
                            x: .value("Month", point.month),
                            y: .value("Income", point.income),
                            width: .fixed(10)
                        )
                        .position(by: .value("Type", "Income"))
                        .foregroundStyle(Color.income)
                        .cornerRadius(3)

                        BarMark(
                            x: .value("Month", point.month),
                            y: .value("Expense", point.expense),
                            width: .fixed(10)
                        )
                        .position(by: .value("Type", "Expense"))
                        .foregroundStyle(Color.expense)
                        .cornerRadius(3)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text(v.asCompactCurrency)
                                    .customFont(.regular, Typography.caption2)
                            }
                        }
                    }
                }
                .frame(height: 180)
            }
        }
    }
}

struct LegendDot: View {
    let color: Color
    let label: LocalizedStringKey

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .customFont(.regular, Typography.caption2)
                .foregroundStyle(.subtitle)
        }
    }
}
