//
//  NeracaPresenter.swift
//  Jesuit
//
//  Presenter for the Neraca (balance sheet) statement screen. Loads the
//  balance-sheet summary as of a chosen date and shapes it into statement rows
//  (sections, lines, grand totals) for an accounting-statement-style layout.
//
//  The API returns roll-up totals only (assets/liabilities/equity); `rows` is
//  built hierarchy-ready (via `indent`) so per-account line items render
//  unchanged if the backend later exposes them.
//

import SwiftUI
import Observation

/// One line of the rendered statement.
struct StatementRow: Identifiable {
    enum Style { case section, line, subtotal, grandTotal }
    let id = UUID()
    let label: String
    let amount: Double?   // nil for a pure header
    let style: Style
    var indent: Int = 0   // 0 today; > 0 once nested line items arrive
}

@Observable
@MainActor
final class NeracaPresenter {
    private let repository: DashboardRepositoryProtocol
    private let session: AuthSession

    /// Snapshot date — the statement is "Per <asOf>".
    private(set) var asOf: Date = .now
    private(set) var state: AppState<BalanceSheetSummary> = .idle

    init(repository: DashboardRepositoryProtocol, session: AuthSession) {
        self.repository = repository
        self.session = session
    }

    var organization: String { session.organization }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let error) = state { return LoginPresenter.message(for: error) }
        return nil
    }

    var summary: BalanceSheetSummary? {
        if case .success(let s) = state { return s }
        return nil
    }

    func load() async {
        state = .loading
        do {
            state = .success(try await repository.fetchBalanceSheet(asOf: asOf))
        } catch {
            state = .error(error)
        }
    }

    /// Changes the snapshot date and reloads.
    func setDate(_ date: Date) async {
        guard date != asOf else { return }
        asOf = date
        await load()
    }

    /// The statement laid out as Harta / Kewajiban / Modal with grand totals.
    /// Mirrors a printed balance sheet's TOTAL ASSETS / TOTAL LIABILITIES & EQUITIES.
    var rows: [StatementRow] {
        guard let s = summary else { return [] }
        return [
            StatementRow(label: "Harta", amount: nil, style: .section),
            StatementRow(label: "Total Harta", amount: s.assets, style: .line),
            StatementRow(label: "TOTAL HARTA", amount: s.assets, style: .grandTotal),

            StatementRow(label: "Kewajiban", amount: nil, style: .section),
            StatementRow(label: "Total Kewajiban", amount: s.liabilities, style: .line),

            StatementRow(label: "Modal", amount: nil, style: .section),
            StatementRow(label: "Total Modal", amount: s.equity, style: .line),
            StatementRow(label: "TOTAL KEWAJIBAN & MODAL", amount: s.liabilities + s.equity, style: .grandTotal),
        ]
    }
}
