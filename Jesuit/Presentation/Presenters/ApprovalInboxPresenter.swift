//
//  ApprovalInboxPresenter.swift
//  Jesuit
//
//  Presenter for the Approval Inbox: sweeps every page of penerimaan and
//  pengeluaran once and keeps only the records still waiting for approval, so an
//  approver sees everything pending in one place. The list endpoint has no
//  server-side status filter, so the sweep + client-side filter mirrors
//  LaporanPresenter.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class ApprovalInboxPresenter {
    /// A pending transaction tagged with its kind, so the row can open the right
    /// edit form in the shared detail sheet (receipts and disbursements differ).
    struct InboxItem: Identifiable, Hashable, Sendable {
        let receipt: CashReceipt
        let kind: CashReceiptDetailSheet.Kind
        var id: String { receipt.id }

        static func == (lhs: InboxItem, rhs: InboxItem) -> Bool { lhs.id == rhs.id && lhs.kind == rhs.kind }
        func hash(into hasher: inout Hasher) { hasher.combine(id); hasher.combine(kind) }
    }

    private let repository: CashReceiptRepositoryProtocol

    /// Page size and safety cap for the full-pagination sweep (matches LaporanPresenter).
    private let pageSize = 100
    private let maxPages = 50

    private(set) var state: AppState<[InboxItem]> = .idle
    private(set) var items: [InboxItem] = []

    /// Exact count of pending transactions — the sweep already loads them all.
    var pendingCount: Int { items.count }

    /// Cheap waiting count for the More-tab badge: reads the server-computed
    /// `counts.waiting` from one page of each stream — no full sweep.
    private(set) var badgeCount = 0

    func loadBadge() async {
        async let receipts = try? repository.fetchReceipts(page: 1, limit: 1)
        async let disbursements = try? repository.fetchDisbursements(page: 1, limit: 1)
        badgeCount = (await receipts?.counts?.waiting ?? 0) + (await disbursements?.counts?.waiting ?? 0)
    }

    init(repository: CashReceiptRepositoryProtocol) {
        self.repository = repository
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let error) = state { return LoginPresenter.message(for: error) }
        return nil
    }

    func load() async {
        state = .loading
        do {
            async let receipts = fetchAll(.receipt)
            async let disbursements = fetchAll(.disbursement)
            let pendingReceipts = try await receipts
                .filter { $0.status == .pendingApproval }
                .map { InboxItem(receipt: $0, kind: .receipt) }
            let pendingDisbursements = try await disbursements
                .filter { $0.status == .pendingApproval }
                .map { InboxItem(receipt: $0, kind: .disbursement) }

            // Merge, dedupe by id, newest first (ties broken by number for stability).
            var seen = Set<String>()
            items = (pendingReceipts + pendingDisbursements)
                .filter { seen.insert($0.id).inserted }
                .sorted {
                    $0.receipt.date != $1.receipt.date
                        ? $0.receipt.date > $1.receipt.date
                        : $0.receipt.number.localizedStandardCompare($1.receipt.number) == .orderedDescending
                }
            state = items.isEmpty ? .empty : .success(items)
        } catch {
            items = []
            state = .error(error)
        }
    }

    private enum TxType { case receipt, disbursement }

    /// Loops every page of the given transaction type, stopping at the reported
    /// total pages (capped for safety). Copied from LaporanPresenter.
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
}
