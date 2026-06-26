//
//  TransferPresenter.swift
//  Jesuit
//
//  Presenter for the Transfer Dana (fund transfers) tab: loads transfers from
//  the finance API with client-side status filtering / search / load-more, and
//  drives the create/edit form. Account/branch/FX lookups are reused from the
//  cash-receipt repository.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class TransferPresenter {
    private let repository: FundTransferRepositoryProtocol
    /// Reused for the account/branch pickers and the FX rate (the transfer
    /// endpoint has no picker endpoints of its own).
    private let lookups: CashReceiptRepositoryProtocol

    /// Status filter — the four API statuses plus "All" (mirrors Penerimaan).
    enum Filter: String, CaseIterable, Identifiable, Sendable {
        case all      = "Semua"
        case draft    = "Draft"
        case waiting  = "Menunggu"
        case posted   = "Disetujui"
        case rejected = "Ditolak"
        var id: String { rawValue }

        static let quickChips: [Filter] = [.all, .draft, .waiting]

        var status: ReceiptStatus? {
            switch self {
            case .all:      return nil
            case .draft:    return .draft
            case .waiting:  return .pendingApproval
            case .posted:   return .approved
            case .rejected: return .rejected
            }
        }
    }

    var filter: Filter = .all
    var searchText: String = ""

    private(set) var transfers: [FundTransfer] = []
    private(set) var state: AppState<[FundTransfer]> = .idle

    /// id → account name, resolved from the cash-accounts lookup so list rows can
    /// show "from → to" (the list payload carries only account ids).
    private(set) var accountNames: [String: String] = [:]

    /// Set when the transfer saved but some attachments failed to upload.
    var attachmentWarning: String?

    /// True when the last `loadMore()` page fetch failed, so the list offers a retry.
    private(set) var loadMoreFailed = false

    private(set) var serverCounts: CashTransactionCounts?

    private let pageSize = 10
    private var page = 1
    private var totalPages = 1

    init(repository: FundTransferRepositoryProtocol, lookups: CashReceiptRepositoryProtocol) {
        self.repository = repository
        self.lookups = lookups
    }

    var isLoading: Bool {
        switch state {
        case .idle, .loading: return true
        default: return false
        }
    }

    var errorMessage: String? {
        if case .error(let error) = state { return LoginPresenter.message(for: error) }
        return nil
    }

    var isLoadingMore: Bool {
        if case .loadmore = state { return true }
        return false
    }

    var canLoadMore: Bool { page < totalPages }

    func load() async {
        state = .loading
        do {
            let result = try await repository.fetchTransfers(page: 1, limit: pageSize)
            transfers = result.transfers
            serverCounts = result.counts
            page = 1
            totalPages = result.totalPages
            state = result.transfers.isEmpty ? .empty : .success(result.transfers)
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            transfers = []
            serverCounts = nil
            state = .error(error)
        }
    }

    func loadMore() async {
        guard canLoadMore, case .success = state else { return }
        state = .loadmore
        loadMoreFailed = false
        do {
            let result = try await repository.fetchTransfers(page: page + 1, limit: pageSize)
            page += 1
            totalPages = result.totalPages
            let seen = Set(transfers.map(\.id))
            transfers += result.transfers.filter { !seen.contains($0.id) }
        } catch {
            loadMoreFailed = true
        }
        state = .success(transfers)
    }

    /// Loads the cash-account id→name map for resolving the "from → to" route on
    /// each row. No-op visual on failure (rows fall back to "—").
    func loadAccounts() async {
        // Resolve against asset accounts (cash/bank + receivables/etc.) — a leg can
        // be any asset account, which the cash/bank-only lookup would exclude.
        if let accounts = try? await lookups.fetchAssetAccounts() {
            accountNames = Dictionary(accounts.map { ($0.id, $0.name) }, uniquingKeysWith: { first, _ in first })
        }
    }

    /// Resolved account name, or "" when the id isn't among the loaded cash/bank
    /// accounts (inactive / non-cash account, or names not loaded yet) so the row
    /// can omit the unresolved side instead of showing a bare "—".
    func accountName(for id: String?) -> String {
        guard let id else { return "" }
        return accountNames[id] ?? ""
    }

    // MARK: - Derived

    var filtered: [FundTransfer] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        let status = filter.status
        return transfers
            .filter { status == nil || $0.status == status }
            .filter { query.isEmpty
                || $0.number.lowercased().contains(query)
                || $0.description.lowercased().contains(query) }
    }

    func count(for status: ReceiptStatus?) -> Int {
        if let counts = serverCounts {
            switch status {
            case .none:             return counts.all ?? transfers.count
            case .draft:            return counts.draft ?? 0
            case .pendingApproval:  return counts.waiting ?? 0
            case .approved:         return counts.posted ?? 0
            case .rejected:         return counts.rejected ?? 0
            }
        }
        guard let status else { return transfers.count }
        return transfers.filter { $0.status == status }.count
    }

    // MARK: - Create / edit form

    /// Drives the create-transfer sheet: header fields plus the FX leg and the
    /// save lifecycle. A transfer has no journal lines.
    @Observable
    @MainActor
    final class CreateForm {
        var date: Date = .now
        var description: String = ""
        var fromAccountId: String?
        var fromBranchId: String?
        var toAccountId: String?
        var toBranchId: String?
        var amountText: String = ""           // IDR digits — the stored amount
        var foreignAmountText: String = ""    // foreign decimal (FX leg only)
        var exchangeRate: Double = 1          // IDR per 1 foreign unit

        var attachments: [CashAttachment] = []
        var existingAttachments: [CashLineAttachment] = []

        private(set) var editId: String?
        private(set) var accounts: [AccountDTO] = []
        private(set) var branches: [BranchDTO] = []
        private(set) var saveState: AppState<Bool> = .idle

        var isEditing: Bool { editId != nil }

        var amount: Double { Double(amountText) ?? 0 }

        private func currency(of id: String?) -> String {
            accounts.first { $0.id == id }?.currencyCode ?? "IDR"
        }
        var fromCurrency: String { currency(of: fromAccountId) }
        var toCurrency: String { currency(of: toAccountId) }

        /// Source and destination resolve to the same account — an invalid transfer.
        var sameAccount: Bool {
            fromAccountId != nil && fromAccountId == toAccountId
        }

        /// Both legs picked and in different currencies → an FX transfer.
        var isForeign: Bool {
            fromAccountId != nil && toAccountId != nil
                && fromCurrency.uppercased() != toCurrency.uppercased()
        }

        /// The non-IDR currency code (FX leg). "" when same-currency.
        var foreignCurrency: String {
            if fromCurrency.uppercased() != "IDR" { return fromCurrency }
            if toCurrency.uppercased() != "IDR" { return toCurrency }
            return ""
        }

        var foreignAmount: Double {
            Double(foreignAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0
        }

        var isSaving: Bool {
            if case .loading = saveState { return true }
            return false
        }

        var errorMessage: String? {
            if case .error(let error) = saveState { return LoginPresenter.message(for: error) }
            return nil
        }

        var canSave: Bool {
            guard let from = fromAccountId, let to = toAccountId,
                  fromBranchId != nil, toBranchId != nil else { return false }
            return from != to && amount > 0 && !isSaving
        }

        func accountName(for id: String?) -> String? {
            accounts.first { $0.id == id }.map { acc in
                acc.code.map { "\($0) — \(acc.name)" } ?? acc.name
            }
        }

        func setOptions(accounts: [AccountDTO], branches: [BranchDTO]) {
            self.accounts = accounts
            self.branches = branches
            let defaultBranch = (branches.first { $0.isDefault == true } ?? branches.first)?.id
            if fromBranchId == nil { fromBranchId = defaultBranch }
            if toBranchId == nil { toBranchId = defaultBranch }
        }

        /// Seeds the form from an existing transfer's detail for editing.
        func seed(from detail: FundTransferDetail) {
            editId = detail.id
            date = detail.date
            description = detail.description
            fromAccountId = detail.fromAccountId
            toAccountId = detail.toAccountId
            amountText = String(Int(detail.amount))
            existingAttachments = detail.attachments
            if detail.isForeign {
                exchangeRate = detail.exchangeRate > 0 ? detail.exchangeRate : 1
                foreignAmountText = detail.originalAmount > 0
                    ? Self.foreignString(detail.originalAmount) : ""
            }
            // Branch ids aren't always resolvable from the detail's names, so the
            // defaults from `setOptions` stand in until the user changes them.
        }

        /// Formats a computed foreign amount: drops the decimal when whole.
        static func foreignString(_ value: Double) -> String {
            if value == value.rounded() { return String(Int(value.rounded())) }
            return String(format: "%.2f", value)
        }

        /// Recompute IDR from foreign × rate (when the user edits foreign/rate).
        func recomputeIDRFromForeign() {
            guard exchangeRate > 0 else { return }
            let rp = (foreignAmount * exchangeRate).rounded()
            amountText = rp > 0 ? String(Int(rp)) : ""
        }

        /// Recompute the foreign field from IDR ÷ rate (when the user edits IDR).
        func recomputeForeignFromIDR() {
            guard isForeign, exchangeRate > 0, amount > 0 else { return }
            foreignAmountText = Self.foreignString(amount / exchangeRate)
        }

        func beginSave() { saveState = .loading }
        func finishSave() { saveState = .success(true) }
        func failSave(_ error: Error) { saveState = .error(error) }
    }

    var form = CreateForm()

    func startCreate() { form = CreateForm() }

    func startEditing(_ detail: FundTransferDetail) {
        let f = CreateForm()
        f.seed(from: detail)
        form = f
    }

    /// Loads the account + branch pickers for the create sheet. Transfer legs are
    /// asset accounts (cash/bank + receivables/etc.), matching the web form.
    func loadFormOptions() async {
        async let accountsResult = try? lookups.fetchAssetAccounts()
        async let branchesResult = try? lookups.fetchBranches()
        let accounts = await accountsResult ?? []
        let branches = await branchesResult ?? []
        form.setOptions(accounts: accounts, branches: branches)
    }

    /// Reacts to an account change: for an FX transfer, fetches a fresh foreign→IDR
    /// rate and recomputes the IDR amount; resets to 1 for same-currency.
    func onAccountChanged() async {
        guard form.isForeign, !form.foreignCurrency.isEmpty else {
            form.exchangeRate = 1
            return
        }
        if let rate = try? await lookups.fetchExchangeRate(base: form.foreignCurrency), rate > 0 {
            form.exchangeRate = rate
            form.recomputeIDRFromForeign()
        }
    }

    /// Saves the form: create (draft/submit) or update (PUT / submit), then
    /// uploads any pending attachments. Returns `true` so the caller dismisses.
    func save(submit: Bool) async -> Bool {
        guard form.canSave,
              let fromAccountId = form.fromAccountId,
              let fromBranchId = form.fromBranchId,
              let toAccountId = form.toAccountId,
              let toBranchId = form.toBranchId else { return false }

        form.beginSave()
        let request = CreateFundTransferRequest(
            date: form.date,
            description: form.description.trimmingCharacters(in: .whitespaces),
            fromAccountId: fromAccountId,
            fromBranchId: fromBranchId,
            toAccountId: toAccountId,
            toBranchId: toBranchId,
            amount: form.amount,
            fromCurrencyCode: form.fromCurrency,
            toCurrencyCode: form.toCurrency,
            exchangeRate: form.exchangeRate,
            originalAmount: form.foreignAmount
        )
        attachmentWarning = nil
        do {
            let savedId: String
            if let editId = form.editId {
                let dto = submit
                    ? try await repository.updateAndSubmit(id: editId, request: request)
                    : try await repository.update(id: editId, request: request)
                savedId = dto.id
            } else {
                let saved = submit
                    ? try await repository.submit(request)
                    : try await repository.saveDraft(request)
                savedId = saved.id
            }
            let failed = await uploadAttachments(id: savedId)
            if failed > 0 {
                attachmentWarning = "Transfer tersimpan, tetapi \(failed) lampiran gagal diunggah. Buka kembali untuk mencoba lagi."
            }
            form.finishSave()
            form = CreateForm()
            await load()
            return true
        } catch {
            form.failSave(error)
            return false
        }
    }

    /// Uploads each newly-picked attachment to the saved transfer. Returns the
    /// number that failed. ponytail: upload-after-create; fold into a create
    /// multipart if the BE confirms `attachments_n` support like cash-transactions.
    private func uploadAttachments(id: String) async -> Int {
        var failed = 0
        for attachment in form.attachments {
            do {
                _ = try await repository.uploadAttachment(id: id, attachment: attachment)
            } catch {
                failed += 1
            }
        }
        return failed
    }
}
