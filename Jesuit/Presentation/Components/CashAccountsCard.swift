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
    /// Max rows shown on the dashboard card.
    var visibleLimit: Int = 5
    /// Tapped "show all" — the host opens the full accounts list page.
    var onShowAll: () -> Void = {}

    /// Accounts that actually carry a balance, largest magnitude first.
    /// Zero-balance accounts are noise on a list of hundreds.
    private var activeAccounts: [CashAccount] {
        accounts
            .filter { $0.balance != 0 }
            .sorted { abs($0.balance) > abs($1.balance) }
    }

    /// Top rows shown on the card.
    private var visibleAccounts: [CashAccount] {
        Array(activeAccounts.prefix(visibleLimit))
    }

    /// Active accounts not shown on the card.
    private var hiddenCount: Int {
        max(activeAccounts.count - visibleLimit, 0)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            if visibleAccounts.isEmpty {
                Text("Belum ada saldo")
                    .customFont(.regular, Typography.callout)
                    .foregroundStyle(.subtitle)
            } else {
                VStack(spacing: 12) {
                    ForEach(visibleAccounts) { account in
                        accountRow(account)
                    }
                }
            }

            if hiddenCount > 0 {
                showMoreButton
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var showMoreButton: some View {
        Button(action: onShowAll) {
            HStack(spacing: 6) {
                Text("+\(hiddenCount) Rekening Lainnya")
                    .customFont(.semibold, Typography.callout)
                Image(systemName: "chevron.right")
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
