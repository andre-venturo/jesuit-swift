//
//  InvoiceRow.swift
//  Jesuit
//
//  Single invoice list row with status pill.
//

import SwiftUI

struct InvoiceRow: View {
    let invoice: Invoice

    private var statusColor: Color {
        switch invoice.status {
        case .paid: return .income
        case .pending: return .orange
        case .overdue: return .expense
        case .draft: return .secondary
        }
    }

    var body: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(invoice.customer)
                    .customFont(.semibold, Typography.body)
                    .foregroundStyle(.title)
                Text("\(invoice.number) · Due \(invoice.dueDate.short)")
                    .customFont(.regular, Typography.caption)
                    .foregroundStyle(.subtitle)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 3) {
                Text(invoice.amount.asCurrency)
                    .customFont(.semibold, Typography.body)
                    .foregroundStyle(.title)
                Text(LocalizedStringKey(invoice.status.rawValue))
                    .customFont(.semibold, Typography.caption2)
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.12))
                    .clipShape(Capsule())
            }
        }
        .padding(16)
    }
}
