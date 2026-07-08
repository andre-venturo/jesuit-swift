//
//  ArusKasPresenter.swift
//  Jesuit
//
//  Arus Kas (cash flow statement): opening cash balance, period inflows and
//  outflows, net movement and closing balance — overall and per cash
//  account. Computed client-side from the full transaction sweep.
//

import Foundation
import Observation

/// The period's cash flow, overall and per account.
struct CashFlowStatement: Sendable {
    struct AccountFlow: Identifiable, Sendable {
        let id: String
        let name: String
        let opening: Double
        let inflow: Double
        let outflow: Double
        var closing: Double { opening + inflow - outflow }
    }

    let opening: Double
    let inflow: Double
    let outflow: Double
    let perAccount: [AccountFlow]

    var net: Double { inflow - outflow }
    var closing: Double { opening + net }
    var isEmpty: Bool { inflow == 0 && outflow == 0 }
}

@Observable
@MainActor
final class ArusKasPresenter {
    private let repository: CashReceiptRepositoryProtocol

    let period = ReportPeriod()
    private(set) var state: AppState<CashFlowStatement> = .idle
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

    var statement: CashFlowStatement? {
        if case .success(let value) = state { return value }
        return nil
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

    private func recompute() {
        guard let sweep else { return }
        let range = period.range

        // (transaction, signedAmount): receipts add, disbursements subtract.
        let all = sweep.receipts.map { ($0, $0.amount) } + sweep.disbursements.map { ($0, -$0.amount) }
        let grouped = Dictionary(grouping: all) { $0.0.cashAccountId ?? "" }

        let perAccount: [CashFlowStatement.AccountFlow] = grouped.compactMap { accountId, entries in
            let opening = entries.filter { $0.0.date < range.start }.reduce(0) { $0 + $1.1 }
            let inRange = entries.filter { $0.0.date >= range.start && $0.0.date <= range.end }
            let inflow = inRange.filter { $0.1 > 0 }.reduce(0) { $0 + $1.1 }
            let outflow = inRange.filter { $0.1 < 0 }.reduce(0) { $0 - $1.1 }
            // Skip accounts with no history at all in this period.
            guard opening != 0 || inflow != 0 || outflow != 0 else { return nil }
            let name = sweep.accountNames[accountId] ?? inRange.first?.0.account ?? "Tanpa Akun"
            return CashFlowStatement.AccountFlow(
                id: accountId, name: name, opening: opening, inflow: inflow, outflow: outflow
            )
        }
        .sorted { $0.name < $1.name }

        let statement = CashFlowStatement(
            opening: perAccount.reduce(0) { $0 + $1.opening },
            inflow: perAccount.reduce(0) { $0 + $1.inflow },
            outflow: perAccount.reduce(0) { $0 + $1.outflow },
            perAccount: perAccount
        )
        state = statement.isEmpty ? .empty : .success(statement)
    }
}
