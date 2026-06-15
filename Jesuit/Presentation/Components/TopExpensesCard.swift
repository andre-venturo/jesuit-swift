//
//  TopExpensesCard.swift
//  Jesuit
//
//  Dashboard "Top Expenses": total banner, a proportional breakdown bar and a
//  per-category list with share percentages.
//

import SwiftUI

struct TopExpensesCard: View {
    let total: Double
    let breakdown: [ExpenseBreakdown]

    var body: some View {
        VStack(spacing: 16) {
            totalBanner

            if breakdown.isEmpty {
                emptyState
            } else {
                proportionBar
                breakdownList
            }
        }
    }

    // MARK: - Total banner

    private var totalBanner: some View {
        VStack(spacing: 6) {
            Text("Total Expenses")
                .customFont(.semibold, 18)
                .foregroundStyle(.orange)
            Text(total.asIDR)
                .customFont(.bold, 30)
                .foregroundStyle(.title)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    // MARK: - Proportion bar

    private var proportionBar: some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(breakdown) { item in
                    color(for: item.color)
                        .frame(width: max(4, geo.size.width * share(item)))
                }
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    // MARK: - List

    private var breakdownList: some View {
        VStack(spacing: 16) {
            ForEach(breakdown) { item in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: item.color))
                        .frame(width: 14, height: 14)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.category)
                            .customFont(.medium, 18)
                            .foregroundStyle(.title)
                        Text(percentLabel(item))
                            .customFont(.regular, 13)
                            .foregroundStyle(.subtitle)
                    }

                    Spacer()

                    Text(item.amount.asIDR)
                        .customFont(.semibold, 18)
                        .foregroundStyle(.title)
                }
            }
        }
    }

    private var emptyState: some View {
        Text("No expenses recorded in the selected date range.")
            .customFont(.regular, 16)
            .foregroundStyle(.subtitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 12)
    }

    // MARK: - Helpers

    private func share(_ item: ExpenseBreakdown) -> Double {
        total > 0 ? item.amount / total : 0
    }

    private func percentLabel(_ item: ExpenseBreakdown) -> String {
        let pct = share(item) * 100
        // Indonesian-style decimal comma, matching the web UI ("100,0%").
        return String(format: "%.1f%%", pct).replacingOccurrences(of: ".", with: ",")
    }

    private func color(for c: ExpenseBreakdownColor) -> Color {
        switch c {
        case .blue:   return Color(red: 0.30, green: 0.56, blue: 1.0)
        case .teal:   return Color(red: 0.20, green: 0.75, blue: 0.70)
        case .orange: return .orange
        case .purple: return Color(red: 0.58, green: 0.44, blue: 0.86)
        case .pink:   return Color(red: 0.92, green: 0.45, blue: 0.62)
        case .gray:   return Color.gray
        }
    }
}
