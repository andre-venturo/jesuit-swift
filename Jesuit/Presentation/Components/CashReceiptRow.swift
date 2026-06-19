//
//  CashReceiptRow.swift
//  Jesuit
//
//  Single cash-receipt row: primary title + amount, a date • number subtitle,
//  the approval status and a trailing actions menu.
//

import SwiftUI

struct CashReceiptRow: View {
    let receipt: CashReceipt

    /// Primary line: the description if present, otherwise the account name.
    private var title: String {
        receipt.description.isEmpty ? receipt.account : receipt.description
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: receipt.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ListMetrics.rowLineSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .customFont(.bold, ListMetrics.titleSize - 2)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(receipt.amount.asIDR)
                    .customFont(.bold, ListMetrics.titleSize - 2)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(spacing: 8) {
                Text(dateLabel)
                    .customFont(.regular, ListMetrics.metaSize - 1)
                    .foregroundStyle(.subtitle)
                Circle()
                    .fill(Color.subtitle)
                    .frame(width: 4, height: 4)
                Text(receipt.number)
                    .customFont(.regular, ListMetrics.metaSize - 1)
                    .foregroundStyle(.subtitle)
            }

            HStack {
                Text(receipt.status.rawValue.uppercased())
                    .customFont(.medium, ListMetrics.statusSize - 1)
                    .foregroundStyle(receipt.status.tint)
                Spacer()
                Image(systemName: "ellipsis")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.subtitle)
            }
        }
        .padding(.vertical, ListMetrics.rowVerticalPadding)
    }
}
