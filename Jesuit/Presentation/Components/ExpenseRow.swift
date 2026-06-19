//
//  ExpenseRow.swift
//  Jesuit
//
//  Single expense row: category + amount, a date line and the billing status.
//

import SwiftUI

struct ExpenseRow: View {
    let expense: Expense

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: expense.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ListMetrics.rowLineSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(expense.category)
                    .customFont(.bold, ListMetrics.titleSize - 2)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(expense.amount.asIDR)
                    .customFont(.bold, ListMetrics.titleSize - 2)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            Text(dateLabel)
                .customFont(.regular, ListMetrics.metaSize - 1)
                .foregroundStyle(.subtitle)

            HStack {
                Text(expense.billing.rawValue.uppercased())
                    .customFont(.medium, ListMetrics.statusSize - 1)
                    .foregroundStyle(.subtitle)
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.subtitle)
            }
        }
        .padding(.vertical, ListMetrics.rowVerticalPadding)
    }
}
