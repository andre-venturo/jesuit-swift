//
//  ContactRow.swift
//  Jesuit
//
//  Single customer list row: avatar, name, and Receivables / Credits columns.
//

import SwiftUI

struct ContactRow: View {
    let contact: Contact

    var body: some View {
        HStack(alignment: .top, spacing: ListMetrics.horizontalInset) {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 52, height: 52)
                .overlay(
                    Text(contact.initials)
                        .customFont(.semibold, 17)
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: ListMetrics.rowLineSpacing) {
                Text(contact.name)
                    .customFont(.bold, ListMetrics.titleSize)
                    .foregroundStyle(.title)

                HStack(alignment: .top, spacing: 0) {
                    amountColumn(title: "Receivables", value: contact.receivables)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    amountColumn(title: "Credits", value: contact.credits)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(.vertical, ListMetrics.rowVerticalPadding)
    }

    private func amountColumn(title: String, value: Double) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .customFont(.regular, ListMetrics.metaSize)
                .foregroundStyle(.subtitle)
            Text(value.asIDR)
                .customFont(.semibold, ListMetrics.titleSize - 2)
                .foregroundStyle(.title)
        }
    }
}
