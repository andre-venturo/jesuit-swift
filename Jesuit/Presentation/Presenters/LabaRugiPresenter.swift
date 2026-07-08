//
//  LabaRugiPresenter.swift
//  Jesuit
//
//  Laba Rugi (profit & loss): revenue, expenses and net profit for the
//  selected period, from the dashboard profit-loss endpoint (the same
//  source as Home's cash-flow card).
//

import Foundation
import Observation

@Observable
@MainActor
final class LabaRugiPresenter {
    private let repository: DashboardRepositoryProtocol

    let period = ReportPeriod()
    private(set) var state: AppState<ProfitLossSummary> = .idle

    init(repository: DashboardRepositoryProtocol) {
        self.repository = repository
        period.onChange = { [weak self] in
            guard let self else { return }
            Task { await self.load(forceReload: true) }
        }
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let error) = state { return LoginPresenter.message(for: error) }
        return nil
    }

    var summary: ProfitLossSummary? {
        if case .success(let value) = state { return value }
        return nil
    }

    /// Unlike the sweep-based reports this hits the network per period change
    /// (the endpoint takes the range server-side).
    func load(forceReload: Bool = false) async {
        if case .success = state, !forceReload { return }
        if summary == nil { state = .loading }  // spinner only when nothing is shown
        do {
            let range = period.range
            let dashboard = try await repository.fetchCashFlow(startDate: range.start, endDate: range.end)
            let summary = dashboard.profitLoss
            state = (summary.revenue == 0 && summary.expenses == 0) ? .empty : .success(summary)
        } catch {
            state = .error(error)
        }
    }
}
