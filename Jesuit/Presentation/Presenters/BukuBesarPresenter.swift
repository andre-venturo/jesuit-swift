//
//  BukuBesarPresenter.swift
//  Jesuit
//
//  Buku Besar (general ledger): every cash account gets its own ledger for
//  the selected period — opening balance (all activity before the range),
//  the in-range movements with a running balance, and a closing balance.
//  Computed client-side from the full transaction sweep.
//

import Foundation
import Observation

/// One account's ledger for the selected period.
struct LedgerAccount: Identifiable, Sendable {
    let id: String
    let name: String
    /// Net balance of everything BEFORE the period (receipts − disbursements).
    let opening: Double
    let rows: [LedgerRow]

    var totalDebit: Double { rows.reduce(0) { $0 + $1.debit } }
    var totalKredit: Double { rows.reduce(0) { $0 + $1.kredit } }
    var closing: Double { opening + totalDebit - totalKredit }
}

/// One movement row: a receipt posts to Debit, a disbursement to Kredit;
/// `saldo` is the running balance after this row.
struct LedgerRow: Identifiable, Sendable {
    let id: String
    let date: Date
    let number: String
    let description: String
    let debit: Double
    let kredit: Double
    let saldo: Double
}

@Observable
@MainActor
final class BukuBesarPresenter {
    private let repository: CashReceiptRepositoryProtocol

    let period = ReportPeriod()
    /// Selected cash-account id (nil == all accounts).
    var accountFilter: String? { didSet { if accountFilter != oldValue { recompute() } } }

    private(set) var state: AppState<[LedgerAccount]> = .idle
    private var sweep: TransactionSweep?

    init(repository: CashReceiptRepositoryProtocol) {
        self.repository = repository
        period.onChange = { [weak self] in self?.recompute() }
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let error) = state { return LoginPresenter.message(for: error) }
        return nil
    }

    var ledgers: [LedgerAccount]? {
        if case .success(let value) = state { return value }
        return nil
    }

    /// Accounts present in the sweep, for the account filter chip.
    var accountOptions: [(id: String, name: String)] {
        guard let sweep else { return [] }
        let ids = Set((sweep.receipts + sweep.disbursements).compactMap(\.cashAccountId))
        return ids.map { (id: $0, name: sweep.accountNames[$0] ?? "—") }.sorted { $0.name < $1.name }
    }

    var accountLabelText: String {
        accountFilter.flatMap { sweep?.accountNames[$0] } ?? "Semua Akun"
    }

    func load(forceReload: Bool = false) async {
        if sweep == nil || forceReload {
            if sweep == nil { state = .loading }  // spinner only on first load
            do {
                sweep = try await TransactionSweep.fetch(repository: repository)
            } catch {
                if sweep == nil { state = .error(error) }  // keep stale data on refresh failure
                return
            }
        }
        recompute()
    }

    /// Groups by cash account and builds each ledger for the active range.
    private func recompute() {
        guard let sweep else { return }
        let range = period.range

        // (transaction, signedAmount): receipts add, disbursements subtract.
        let all = sweep.receipts.map { ($0, $0.amount) } + sweep.disbursements.map { ($0, -$0.amount) }
        let grouped = Dictionary(grouping: all) { $0.0.cashAccountId ?? "" }

        let ledgers: [LedgerAccount] = grouped.compactMap { accountId, entries in
            if let filter = accountFilter, filter != accountId { return nil }

            let opening = entries.filter { $0.0.date < range.start }.reduce(0) { $0 + $1.1 }
            let inRange = entries
                .filter { $0.0.date >= range.start && $0.0.date <= range.end }
                .sorted {
                    $0.0.date != $1.0.date ? $0.0.date < $1.0.date
                        : $0.0.number.localizedStandardCompare($1.0.number) == .orderedAscending
                }
            guard !inRange.isEmpty else { return nil }

            var saldo = opening
            let rows = inRange.map { record, signed in
                saldo += signed
                return LedgerRow(
                    id: record.id,
                    date: record.date,
                    number: record.number,
                    description: record.description,
                    debit: signed > 0 ? signed : 0,
                    kredit: signed < 0 ? -signed : 0,
                    saldo: saldo
                )
            }
            let name = sweep.accountNames[accountId] ?? inRange.first?.0.account ?? "Tanpa Akun"
            return LedgerAccount(id: accountId, name: name, opening: opening, rows: rows)
        }
        .sorted { $0.name < $1.name }

        state = ledgers.isEmpty ? .empty : .success(ledgers)
    }
}
