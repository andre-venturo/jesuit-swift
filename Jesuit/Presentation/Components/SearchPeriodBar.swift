//
//  SearchPeriodBar.swift
//  Jesuit
//
//  Search field paired with a period picker, matching the Penerimaan toolbar.
//

import SwiftUI

struct SearchPeriodBar: View {
    @Binding var searchText: String
    var searchPrompt: LocalizedStringKey = "Cari no. transaksi atau deskripsi…"
    var periodLabel: LocalizedStringKey = "Pilih periode"
    var onPeriodTap: () -> Void = {}

    var body: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.subtitle)
                TextField(searchPrompt, text: $searchText)
                    .font(Font.customFont(.regular, 15))
                    .foregroundStyle(.title)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(.textFieldStroke, lineWidth: 1)
            )

            // Period picker
            Button(action: onPeriodTap) {
                HStack(spacing: 10) {
                    Text(periodLabel)
                        .customFont(.regular, 15)
                        .foregroundStyle(.subtitle)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "calendar")
                        .foregroundStyle(.subtitle)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .frame(width: 170)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(.textFieldStroke, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }
}
