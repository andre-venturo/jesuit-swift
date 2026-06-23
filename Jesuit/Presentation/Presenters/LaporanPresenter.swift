//
//  LaporanPresenter.swift
//  Jesuit
//
//  Presenter for the Laporan (report) screen: pulls all penerimaan and
//  pengeluaran for a selected period from the cash-transactions API (the list
//  endpoint has no server-side date filter, so it paginates fully and
//  aggregates client-side) and computes period totals + a per-account breakdown.
//

import SwiftUI
import Observation

/// Aggregated period report computed from the receipt/disbursement records.
struct ReportSummary: Sendable {
    let penerimaanTotal: Double
    let pengeluaranTotal: Double
    let penerimaanCount: Int
    let pengeluaranCount: Int
    /// Per cash-account breakdown (top accounts, remainder folded into "Lainnya").
    let penerimaanByAccount: [ExpenseBreakdown]
    let pengeluaranByAccount: [ExpenseBreakdown]

    var net: Double { penerimaanTotal - pengeluaranTotal }
    var isEmpty: Bool { penerimaanCount == 0 && pengeluaranCount == 0 }
}

@Observable
@MainActor
final class LaporanPresenter {
    private let repository: CashReceiptRepositoryProtocol

    /// Page size and safety cap for the full-pagination sweep.
    private let pageSize = 100
    private let maxPages = 50
    /// How many accounts to show before folding the rest into "Lainnya".
    private let topAccounts = 6

    // MARK: - Period selection (mirrors HomePresenter)

    var cashFlowPeriod: CashFlowPeriod = .bulanIni {
        didSet {
            guard cashFlowPeriod != oldValue else { return }
            customRange = nil
            periodOffset = 0
            recompute()
        }
    }
    private(set) var periodOffset = 0
    /// User-picked `[start, end]` that overrides `cashFlowPeriod` when set.
    private(set) var customRange: (start: Date, end: Date)?
    var hasCustomRange: Bool { customRange != nil }

    /// The active range: the custom range if set, else the preset shifted by offset.
    private var effectiveRange: (start: Date, end: Date) {
        customRange ?? cashFlowPeriod.dateRange(offset: periodOffset)
    }

    /// Current active range, for seeding the custom-range picker.
    var summaryRange: (start: Date, end: Date) { effectiveRange }

    /// Center label for the stepper / custom range.
    var steppedLabel: String {
        if let range = customRange {
            let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "d MMM"
            let endF = DateFormatter(); endF.locale = Locale(identifier: "id_ID"); endF.dateFormat = "d MMM yyyy"
            return "\(f.string(from: range.start)) – \(endF.string(from: range.end))"
        }
        return cashFlowPeriod.steppedLabel(offset: periodOffset)
    }

    /// Dropdown label: the preset name, or "Custom" when a custom range is set.
    var rangeLabel: String { hasCustomRange ? "Custom" : cashFlowPeriod.rawValue }

    func stepPeriod(by delta: Int) {
        guard !hasCustomRange else { return }
        periodOffset += delta
        recompute()
    }

    func applyCustomRange(start: Date, end: Date) {
        customRange = start <= end ? (start, end) : (end, start)
        recompute()
    }

    // MARK: - State

    private(set) var state: AppState<ReportSummary> = .idle

    /// The full record set, fetched once and re-aggregated per period locally.
    /// The list endpoint has no date filter, so the data is range-independent.
    private var records: (receipts: [CashReceipt], disbursements: [CashReceipt])?

    init(repository: CashReceiptRepositoryProtocol) {
        self.repository = repository
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let error) = state {
            return LoginPresenter.message(for: error)
        }
        return nil
    }

    var summary: ReportSummary? {
        if case .success(let value) = state { return value }
        return nil
    }

    // MARK: - Load

    /// Fetches the full record set once (or again when `forceReload`), then
    /// aggregates for the active range. Period changes go through `recompute()`
    /// and never hit the network.
    func load(forceReload: Bool = false) async {
        if records == nil || forceReload {
            if records == nil { state = .loading }  // spinner only on first load; refresh keeps content
            do {
                async let receipts = fetchAll(.receipt)
                async let disbursements = fetchAll(.disbursement)
                records = (try await receipts, try await disbursements)
            } catch {
                if records == nil { state = .error(error) }  // keep stale data if a refresh fails
                return
            }
        }
        recompute()
    }

    /// Re-aggregates the cached records for the active range. Instant, no network.
    private func recompute() {
        guard let records else { return }  // not loaded yet — load() will call us
        let summary = aggregate(
            receipts: records.receipts,
            disbursements: records.disbursements,
            range: effectiveRange
        )
        state = summary.isEmpty ? .empty : .success(summary)
    }

    private enum TxType { case receipt, disbursement }

    /// Loops every page of the given transaction type and concatenates the
    /// results, stopping at the reported total pages (capped for safety).
    private func fetchAll(_ type: TxType) async throws -> [CashReceipt] {
        var all: [CashReceipt] = []
        var page = 1
        while page <= maxPages {
            let result: CashReceiptPage
            switch type {
            case .receipt:      result = try await repository.fetchReceipts(page: page, limit: pageSize)
            case .disbursement: result = try await repository.fetchDisbursements(page: page, limit: pageSize)
            }
            all.append(contentsOf: result.receipts)
            let totalPages = max(result.totalPages, 1)
            if page >= totalPages || result.receipts.isEmpty { break }
            page += 1
        }
        return all
    }

    // MARK: - Aggregation

    private func aggregate(
        receipts: [CashReceipt],
        disbursements: [CashReceipt],
        range: (start: Date, end: Date)
    ) -> ReportSummary {
        let inRange: (CashReceipt) -> Bool = { $0.date >= range.start && $0.date <= range.end }
        let receiptsInRange = receipts.filter(inRange)
        let disbursementsInRange = disbursements.filter(inRange)

        return ReportSummary(
            penerimaanTotal: receiptsInRange.reduce(0) { $0 + $1.amount },
            pengeluaranTotal: disbursementsInRange.reduce(0) { $0 + $1.amount },
            penerimaanCount: receiptsInRange.count,
            pengeluaranCount: disbursementsInRange.count,
            penerimaanByAccount: breakdown(receiptsInRange),
            pengeluaranByAccount: breakdown(disbursementsInRange)
        )
    }

    /// Groups transactions by cash account, sorts by total desc, keeps the top N
    /// and folds the remainder into a single "Lainnya" slice. Colors cycle
    /// through the shared palette.
    private func breakdown(_ items: [CashReceipt]) -> [ExpenseBreakdown] {
        guard !items.isEmpty else { return [] }
        let totals = Dictionary(grouping: items, by: \.account)
            .map { (account: $0.key.isEmpty ? "Tanpa Akun" : $0.key, amount: $0.value.reduce(0) { $0 + $1.amount }) }
            .sorted { $0.amount > $1.amount }

        let palette = ExpenseBreakdownColor.allCases
        var result: [ExpenseBreakdown] = []
        let head = totals.prefix(topAccounts)
        for (index, entry) in head.enumerated() {
            result.append(ExpenseBreakdown(
                category: entry.account,
                amount: entry.amount,
                color: palette[index % palette.count]
            ))
        }
        let rest = totals.dropFirst(topAccounts)
        if !rest.isEmpty {
            result.append(ExpenseBreakdown(
                category: "Lainnya",
                amount: rest.reduce(0) { $0 + $1.amount },
                color: .gray
            ))
        }
        return result
    }
}
