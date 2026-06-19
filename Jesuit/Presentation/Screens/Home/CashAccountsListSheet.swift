//
//  CashAccountsListSheet.swift
//  Jesuit
//
//  Full "Rekening Kas & Bank" list — every account with a balance, opened from
//  the dashboard card's "+N Rekening Lainnya" button.
//

import SwiftUI

struct CashAccountsListSheet: View {
    let total: Double
    let accounts: [CashAccount]

    @Environment(\.dismiss) private var dismiss

    /// Accounts carrying a balance, largest magnitude first.
    private var activeAccounts: [CashAccount] {
        accounts
            .filter { $0.balance != 0 }
            .sorted { abs($0.balance) > abs($1.balance) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    totalHeader

                    VStack(spacing: 0) {
                        ForEach(Array(activeAccounts.enumerated()), id: \.element.id) { index, account in
                            accountRow(account)
                            if index < activeAccounts.count - 1 {
                                Divider().opacity(0.4).padding(.leading, 16)
                            }
                        }
                    }
                    .background(Color.white.opacity(0.04))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .padding(20)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Rekening Kas & Bank")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.subtitle)
                }
            }
        }
    }

    private var totalHeader: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(total.asRupiah)
                .customFont(.bold, Typography.title)
                .foregroundStyle(total < 0 ? Color.expense : .title)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
            Text("Total Saldo · \(activeAccounts.count) rekening")
                .customFont(.regular, Typography.subhead)
                .foregroundStyle(.subtitle)
        }
    }

    private func accountRow(_ account: CashAccount) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(account.balance < 0 ? Color.expense : Color.income)
                .frame(width: 7, height: 7)
            Text(account.name)
                .customFont(.regular, Typography.callout)
                .foregroundStyle(.title)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(account.balance.asRupiah)
                .customFont(.medium, Typography.callout)
                .foregroundStyle(account.balance < 0 ? Color.expense : .title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
