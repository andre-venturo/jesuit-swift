//
//  ReportSupport.swift
//  Jesuit
//
//  Shared machinery for the report presenters (Buku Besar, Laba Rugi,
//  Arus Kas): the period selection model and the full cash-transactions
//  sweep (the list endpoint has no date filter, so reports paginate
//  everything once and aggregate client-side, like LaporanPresenter).
//

import Foundation
import Observation

/// Period selection shared by the report presenters: a preset
/// (`CashFlowPeriod`) or a custom `[start, end]` range. `onChange` fires on
/// every effective-range change so the owning presenter can recompute.
@Observable
@MainActor
final class ReportPeriod {
    var onChange: (() -> Void)?

    var cashFlowPeriod: CashFlowPeriod = .bulanIni {
        didSet {
            // A custom range must clear even when the user re-picks the preset
            // already stored here (an equal value would otherwise skip the
            // reset below and strand the custom range).
            guard cashFlowPeriod != oldValue || customRange != nil else { return }
            customRange = nil
            onChange?()
        }
    }

    private(set) var customRange: (start: Date, end: Date)?
    var hasCustomRange: Bool { customRange != nil }

    /// The active range: the custom range if set, else the preset.
    var range: (start: Date, end: Date) { customRange ?? cashFlowPeriod.dateRange() }

    func applyCustomRange(start: Date, end: Date) {
        customRange = start <= end ? (start, end) : (end, start)
        onChange?()
    }

    /// Period-chip label. A custom range spanning exactly one whole month (the
    /// month-grid picker's output) reads as "Mei 2026".
    var label: String {
        guard let range = customRange else { return cashFlowPeriod.steppedLabel() }
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
}

/// One full pull of the cash-transactions data set with resolved names:
/// every receipt and disbursement (account column filled in), plus the
/// id → name maps for cash accounts and branches.
struct TransactionSweep: Sendable {
    let receipts: [CashReceipt]
    let disbursements: [CashReceipt]
    let accountNames: [String: String]
    let branchNames: [String: String]

    /// Page size and safety cap for the full-pagination sweep.
    private static let pageSize = 100
    private static let maxPages = 50

    static func fetch(repository: CashReceiptRepositoryProtocol) async throws -> TransactionSweep {
        async let receiptsRaw = fetchAll(repository: repository, disbursements: false)
        async let disbursementsRaw = fetchAll(repository: repository, disbursements: true)
        async let accounts = (try? repository.fetchCashAccounts()) ?? []
        async let branches = (try? repository.fetchBranches()) ?? []

        // Accounts read as "code — name" when a code exists.
        let accountNames = Dictionary(await accounts.map { acc in
            (acc.id, acc.code.map { "\($0) — \(acc.name)" } ?? acc.name)
        }, uniquingKeysWith: { a, _ in a })
        let branchNames = Dictionary(await branches.map { ($0.id, $0.name) },
                                     uniquingKeysWith: { a, _ in a })

        func named(_ r: CashReceipt) -> CashReceipt {
            guard let id = r.cashAccountId, let name = accountNames[id] else { return r }
            return CashReceipt(
                id: r.id, number: r.number, date: r.date, description: r.description,
                account: name, amount: r.amount, currencyCode: r.currencyCode, status: r.status,
                createdAt: r.createdAt, updatedAt: r.updatedAt,
                cashAccountId: r.cashAccountId, branchId: r.branchId
            )
        }

        return TransactionSweep(
            receipts: try await receiptsRaw.map(named),
            disbursements: try await disbursementsRaw.map(named),
            accountNames: accountNames,
            branchNames: branchNames
        )
    }

    /// Loops every page of one transaction type, stopping at the reported
    /// total pages (capped for safety).
    private static func fetchAll(
        repository: CashReceiptRepositoryProtocol,
        disbursements: Bool
    ) async throws -> [CashReceipt] {
        var all: [CashReceipt] = []
        var page = 1
        while page <= maxPages {
            let result = disbursements
                ? try await repository.fetchDisbursements(page: page, limit: pageSize)
                : try await repository.fetchReceipts(page: page, limit: pageSize)
            all.append(contentsOf: result.receipts)
            let totalPages = max(result.totalPages, 1)
            if page >= totalPages || result.receipts.isEmpty { break }
            page += 1
        }
        return all
    }
}
