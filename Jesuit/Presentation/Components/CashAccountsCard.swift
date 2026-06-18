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
        VStack(alignment: .leading, spacing: 14) {
            header

            VStack(spacing: 12) {
                ForEach(visibleAccounts) { account in
                    accountRow(account)
                }
            }

            if canToggle {
                showMoreButton
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var showMoreButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
        } label: {
            HStack(spacing: 6) {
                Text(isExpanded ? "Tampilkan Lebih Sedikit" : "Tampilkan Semua (\(accounts.count))")
                    .customFont(.semibold, Typography.callout)
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(.accent)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
        }
    }

    // MARK: - Header (title + hero total)

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Rekening Kas & Bank")
                .customFont(.bold, Typography.body)
                .foregroundStyle(.title)

            VStack(alignment: .leading, spacing: 2) {
                Text(total.asRupiah)
                    .customFont(.bold, Typography.title)
                    .foregroundStyle(total < 0 ? Color.expense : .title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                Text("Total Saldo")
                    .customFont(.regular, Typography.subhead)
                    .foregroundStyle(.subtitle)
            }
        }
    }

    // MARK: - Row (dot · name ── balance)

    private func accountRow(_ account: CashAccount) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(account.balance < 0 ? Color.expense : Color.income)
                .frame(width: 7, height: 7)
            Text(account.name)
                .customFont(.regular, Typography.callout)
                .foregroundStyle(.subtitle)
                .lineLimit(1)
            Spacer(minLength: 8)
            Text(account.balance.asRupiah)
                .customFont(.medium, Typography.callout)
                .foregroundStyle(account.balance < 0 ? Color.expense : .title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }
}
