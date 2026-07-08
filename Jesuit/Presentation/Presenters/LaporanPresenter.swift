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
    /// In-range transactions (newest first), for the journal table + exports.
    let penerimaanRows: [CashReceipt]
    let pengeluaranRows: [CashReceipt]

    var net: Double { penerimaanTotal - pengeluaranTotal }
    var isEmpty: Bool { penerimaanCount == 0 && pengeluaranCount == 0 }

    /// All in-range transactions as journal rows, oldest first (cash-book view:
    /// penerimaan posts to Debit, pengeluaran to Kredit). Drives both the
    /// journal table and the PDF/CSV exports.
    var journalEntries: [JournalEntry] {
        let debit = penerimaanRows.map { JournalEntry(row: $0, debit: $0.amount, kredit: 0) }
        let kredit = pengeluaranRows.map { JournalEntry(row: $0, debit: 0, kredit: $0.amount) }
        return (debit + kredit).sorted {
            $0.date != $1.date ? $0.date < $1.date
                : $0.number.localizedStandardCompare($1.number) == .orderedAscending
        }
    }
}

/// One row of the cash journal (Jurnal Umum-style) table.
struct JournalEntry: Identifiable, Sendable {
    let id: String
    let date: Date
    let number: String
    let account: String
    let description: String
    let debit: Double
    let kredit: Double

    init(row: CashReceipt, debit: Double, kredit: Double) {
        self.id = row.id
        self.date = row.date
        self.number = row.number
        self.account = row.account.isEmpty ? "Tanpa Akun" : row.account
        self.description = row.description
        self.debit = debit
        self.kredit = kredit
    }
}

@Observable
@MainActor
final class LaporanPresenter {
    private let repository: CashReceiptRepositoryProtocol

    /// Page size and safety cap for the full-pagination sweep.
    private let pageSize = 100
    private let maxPages = 50

    // MARK: - Period selection (mirrors HomePresenter)

    var cashFlowPeriod: CashFlowPeriod = .bulanIni {
        didSet {
            // A custom range must clear even when the user re-picks the preset
            // already stored here (an equal value would otherwise skip the
            // reset below and strand the custom range).
            guard cashFlowPeriod != oldValue || customRange != nil else { return }
            customRange = nil
            recompute()
        }
    }
    /// User-picked `[start, end]` that overrides `cashFlowPeriod` when set.
    private(set) var customRange: (start: Date, end: Date)?
    var hasCustomRange: Bool { customRange != nil }

    /// The active range: the custom range if set, else the preset.
    private var effectiveRange: (start: Date, end: Date) {
        customRange ?? cashFlowPeriod.dateRange()
    }

    /// Current active range, for seeding the custom-range picker.
    var summaryRange: (start: Date, end: Date) { effectiveRange }

    /// Period-chip label: the custom range if set, else the preset period.
    /// A custom range spanning exactly one whole month (the month-grid picker's
    /// output) reads as "Mei 2026" instead of "1 Mei – 31 Mei 2026".
    var steppedLabel: String {
        if let range = customRange {
            let cal = Calendar.current
            if let interval = cal.dateInterval(of: .month, for: range.start),
               let lastDay = cal.date(byAdding: .second, value: -1, to: interval.end),
               cal.isDate(range.start, inSameDayAs: interval.start),
               cal.isDate(range.end, inSameDayAs: lastDay) {
                let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "MMMM yyyy"
                return f.string(from: range.start)
            }
            let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "d MMM"
            let endF = DateFormatter(); endF.locale = Locale(identifier: "id_ID"); endF.dateFormat = "d MMM yyyy"
            return "\(f.string(from: range.start)) – \(endF.string(from: range.end))"
        }
        return cashFlowPeriod.steppedLabel()
    }

    func applyCustomRange(start: Date, end: Date) {
        customRange = start <= end ? (start, end) : (end, start)
        recompute()
    }

    // MARK: - Filters (client-side; the list endpoint has no filter params)

    var statusFilter: ReceiptStatus? { didSet { if statusFilter != oldValue { recompute() } } }
    /// Selected cash-account / branch ids (nil == all).
    var accountFilter: String? { didSet { if accountFilter != oldValue { recompute() } } }
    var branchFilter: String? { didSet { if branchFilter != oldValue { recompute() } } }

    /// Id → display name, resolved from the accounts / branches endpoints (the
    /// transaction list payload carries only ids).
    private var accountNames: [String: String] = [:]
    private var branchNames: [String: String] = [:]

    /// Display names for the ACTIVE branch/account filter, resolved from the full
    /// name maps — used as a picker-option fallback when the filtered id vanishes
    /// from the loaded records (e.g. after a refresh), so the row never shows a
    /// bare placeholder while the filter still applies.
    var accountLabelText: String { accountFilter.flatMap { accountNames[$0] } ?? "Semua Akun" }
    var branchLabelText: String { branchFilter.flatMap { branchNames[$0] } ?? "Semua Cabang & Unit" }

    let statusOptions = ReceiptStatus.allCases

    var hasActiveFilters: Bool { statusFilter != nil || branchFilter != nil || accountFilter != nil }

    func resetFilters() {
        statusFilter = nil
        branchFilter = nil
        accountFilter = nil
    }

    /// Distinct cash accounts / branches present in the loaded records, named.
    var accountOptions: [(id: String, name: String)] { options(\.cashAccountId, names: accountNames) }
    var branchOptions: [(id: String, name: String)] { options(\.branchId, names: branchNames) }

    private func options(_ key: KeyPath<CashReceipt, String?>, names: [String: String]) -> [(id: String, name: String)] {
        guard let records else { return [] }
        let ids = Set((records.receipts + records.disbursements).compactMap { $0[keyPath: key] })
        return ids.map { (id: $0, name: names[$0] ?? "—") }.sorted { $0.name < $1.name }
    }

    // MARK: - State

    private(set) var state: AppState<ReportSummary> = .idle

    /// The full record set, fetched once and re-aggregated per period/filter
    /// locally. The list endpoint has no date filter, so data is range-independent.
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
                async let accounts = try? repository.fetchCashAccounts()
                async let branches = try? repository.fetchBranches()
                await resolveNames(accounts: accounts ?? [], branches: branches ?? [])
                // Fill each record's account column with the resolved cash-account name.
                records = (try await receipts.map(named), try await disbursements.map(named))
            } catch {
                if records == nil { state = .error(error) }  // keep stale data if a refresh fails
                return
            }
        }
        recompute()
    }

    /// Builds the id → name maps. Accounts use "code — name" when a code exists.
    private func resolveNames(accounts: [AccountDTO], branches: [BranchDTO]) {
        accountNames = Dictionary(accounts.map { acc in
            (acc.id, acc.code.map { "\($0) — \(acc.name)" } ?? acc.name)
        }, uniquingKeysWith: { a, _ in a })
        branchNames = Dictionary(branches.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
    }

    /// Returns a copy of the record with its account column set to the resolved
    /// cash-account name (the list payload only carries the id).
    private func named(_ r: CashReceipt) -> CashReceipt {
        guard let id = r.cashAccountId, let name = accountNames[id] else { return r }
        return CashReceipt(
            id: r.id, number: r.number, date: r.date, description: r.description,
            account: name, amount: r.amount, currencyCode: r.currencyCode, status: r.status,
            createdAt: r.createdAt, updatedAt: r.updatedAt,
            cashAccountId: r.cashAccountId, branchId: r.branchId
        )
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
        // Date range + the active Status / Akun / Cabang filters.
        let matches: (CashReceipt) -> Bool = { r in
            r.date >= range.start && r.date <= range.end
                && (self.statusFilter == nil || r.status == self.statusFilter)
                && (self.accountFilter == nil || r.cashAccountId == self.accountFilter)
                && (self.branchFilter == nil || r.branchId == self.branchFilter)
        }
        // Newest first; ties broken by transaction number so the order is stable.
        let byDateDesc: (CashReceipt, CashReceipt) -> Bool = {
            $0.date != $1.date ? $0.date > $1.date
                : $0.number.localizedStandardCompare($1.number) == .orderedDescending
        }
        let receiptsInRange = receipts.filter(matches).sorted(by: byDateDesc)
        let disbursementsInRange = disbursements.filter(matches).sorted(by: byDateDesc)

        return ReportSummary(
            penerimaanTotal: receiptsInRange.reduce(0) { $0 + $1.amount },
            pengeluaranTotal: disbursementsInRange.reduce(0) { $0 + $1.amount },
            penerimaanCount: receiptsInRange.count,
            pengeluaranCount: disbursementsInRange.count,
            penerimaanRows: receiptsInRange,
            pengeluaranRows: disbursementsInRange
        )
    }
}
