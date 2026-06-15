//
//  CashAccountsCard.swift
//  Jesuit
//
//  Dashboard "Rekening Kas & Bank" card: a header with the total balance and a
//  grouped, iOS-style list of per-account balances.
//

import SwiftUI

struct CashAccountsCard: View {
    let total: Double
    let accounts: [CashAccount]
    /// Max rows shown when collapsed.
    var collapsedLimit: Int = 4

    @State private var isExpanded = false

    /// Rows currently visible (all when expanded, else the first `collapsedLimit`).
    private var visibleAccounts: [CashAccount] {
        isExpanded ? accounts : Array(accounts.prefix(collapsedLimit))
    }

    private var canToggle: Bool { accounts.count > collapsedLimit }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)

            ForEach(Array(visibleAccounts.enumerated()), id: \.element.id) { index, account in
                accountRow(account)
                if index < visibleAccounts.count - 1 {
                    Divider().opacity(0.4).padding(.leading, 18)
                }
            }

            if canToggle {
                Divider().opacity(0.4)
                showMoreButton
            }
        }
        .background(Color.white.opacity(0.04))
    }

    private var showMoreButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(isExpanded ? "Tampilkan Lebih Sedikit" : "Tampilkan Semua (\(accounts.count))")
                    .customFont(.semibold, 15)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundStyle(.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            Text("Rekening Kas & Bank")
                .customFont(.bold, 20)
                .foregroundStyle(.title)
            Spacer(minLength: 12)
            VStack(alignment: .trailing, spacing: 4) {
                Text("Total Saldo")
                    .customFont(.regular, 13)
                    .foregroundStyle(.subtitle)
                Text(total.asRupiah)
                    .customFont(.bold, 18)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
        }
        .padding(18)
    }

    // MARK: - Row

    private func accountRow(_ account: CashAccount) -> some View {
        HStack(spacing: 12) {
            Text(account.name)
                .customFont(.regular, 16)
                .foregroundStyle(.title)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(account.balance.asRupiah)
                .customFont(.semibold, 16)
                .foregroundStyle(account.balance < 0 ? Color.expense : .title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
    }
}
