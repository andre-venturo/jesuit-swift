//
//  PengeluaranPresenter.swift
//  Jesuit
//
//  Presenter for the Pengeluaran (expenses) tab: loads cash disbursements from
//  the finance API, then applies status filtering, search and per-status counts
//  for the filter tabs.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class PengeluaranPresenter {
    private let repository: CashReceiptRepositoryProtocol

    /// Top filter chip selection.
    enum Filter: String, CaseIterable, Identifiable, Sendable {
        case all = "All"
        case unpaid = "Unpaid"
        case draft = "Draft"
        var id: String { rawValue }
    }

    /// Sort order for the list (toggled by the sort button).
    enum SortOrder: Sendable { case dateDesc, dateAsc }

    var filter: Filter = .all
    var sortOrder: SortOrder = .dateDesc
    var searchText: String = ""

    private(set) var expenses: [CashReceipt] = []
    private(set) var state: AppState<[CashReceipt]> = .idle

    /// Per-status counts from the API `meta.counts`, used for the tab badges so
    /// they reflect the full result set rather than just the loaded page.
    private(set) var serverCounts: CashTransactionCounts?

    private let pageSize = 25

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

    func toggleSort() {
        sortOrder = sortOrder == .dateDesc ? .dateAsc : .dateDesc
    }

    /// Loads the first page of cash disbursements from the finance API.
    func load() async {
        state = .loading
        do {
            let page = try await repository.fetchDisbursements(page: 1, limit: pageSize)
            expenses = page.receipts
            serverCounts = page.counts
            state = page.receipts.isEmpty ? .empty : .success(page.receipts)
        } catch {
            expenses = []
            serverCounts = nil
            state = .error(error)
        }
    }

    // MARK: - Derived

    /// Expenses after applying the filter chip, search and sort.
    var filtered: [CashReceipt] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return expenses
            .filter { expense in
                switch filter {
                case .all:    return true
                case .unpaid: return expense.status == .pendingApproval
                case .draft:  return expense.status == .draft
                }
            }
            .filter { query.isEmpty
                || $0.number.lowercased().contains(query)
                || $0.description.lowercased().contains(query) }
            .sorted { lhs, rhs in
                switch sortOrder {
                case .dateDesc: return lhs.date > rhs.date
                case .dateAsc:  return lhs.date < rhs.date
                }
            }
    }

    var total: Double { expenses.reduce(0) { $0 + $1.amount } }

    // MARK: - Create expense form

    /// One editable "Detail Baris" row in the create sheet.
    @Observable
    @MainActor
    final class LineDraft: Identifiable {
        let id = UUID()
        var accountId: String?   // Akun Lawan
        var description: String   // Deskripsi
        var amountText: String    // Jumlah (digits only)
        var attachments: [CashAttachment]   // Lampiran

        init(
            accountId: String? = nil,
            description: String = "",
            amountText: String = "",
            attachments: [CashAttachment] = []
        ) {
            self.accountId = accountId
            self.description = description
            self.amountText = amountText
            self.attachments = attachments
        }

        var amount: Double { Double(amountText) ?? 0 }

        var isValid: Bool {
            accountId != nil
                && amount > 0
                && !description.trimmingCharacters(in: .whitespaces).isEmpty
        }

        /// Detached copy for editing; changes only land via `CreateForm.commit`.
        func copy() -> LineDraft {
            LineDraft(accountId: accountId, description: description, amountText: amountText, attachments: attachments)
        }

        /// Overwrites fields from an edited copy (commit on "Tambah").
        func apply(_ other: LineDraft) {
            accountId = other.accountId
            description = other.description
            amountText = other.amountText
            attachments = other.attachments
        }
    }

    /// Drives the create-expense sheet: the header (date + cash account), the
    /// editable lines, picker options and the save lifecycle. Mirrors the web
    /// "Pengeluaran Kas Baru" dialog.
    @Observable
    @MainActor
    final class CreateForm {
        var date: Date = .now
        var cashAccountId: String?          // Akun Kas/Bank (header)
        var lines: [LineDraft] = []

        private(set) var accounts: [AccountDTO] = []
        private var defaultBranchId: String?
        private(set) var saveState: AppState<CashReceipt> = .idle

        var total: Double { lines.reduce(0) { $0 + $1.amount } }

        var isSaving: Bool {
            if case .loading = saveState { return true }
            return false
        }

        var errorMessage: String? {
            if case .error(let error) = saveState {
                return LoginPresenter.message(for: error)
            }
            return nil
        }

        var canSave: Bool {
            cashAccountId != nil
                && !lines.isEmpty
                && lines.allSatisfy(\.isValid)
                && !isSaving
        }

        var cashAccountName: String {
            accountName(for: cashAccountId) ?? "Pilih akun"
        }

        func accountName(for id: String?) -> String? {
            accounts.first { $0.id == id }.map { acc in
                acc.code.map { "\($0) — \(acc.name)" } ?? acc.name
            }
        }

        var branchId: String? { defaultBranchId }
    }

    var form = CreateForm()

    /// Loads the cash-account picker (and default branch) for the create sheet,
    /// preselecting the first cash account and seeding one empty line.
    func loadFormOptions() async {
        async let accountsResult = try? repository.fetchCashAccounts()
        async let branchesResult = try? repository.fetchBranches()
        let accounts = await accountsResult ?? []
        let branches = await branchesResult ?? []

        form.setOptions(accounts: accounts, branches: branches)
    }

    /// Saves the create form, either as a draft or submitted. On success resets
    /// the form, reloads the list and returns `true` so the caller can dismiss.
    func save(submit: Bool) async -> Bool {
        guard form.canSave, let cashAccountId = form.cashAccountId,
              let branchId = form.branchId else { return false }

        form.beginSave()
        let request = CashTransactionRequest(
            type: "disbursement",
            branchId: branchId,
            cashAccountId: cashAccountId,
            date: form.date,
            lines: form.lines.map {
                .init(
                    accountId: $0.accountId ?? cashAccountId,
                    description: $0.description.trimmingCharacters(in: .whitespaces),
                    amount: $0.amount
                )
            }
        )
        let attachments = form.lines.flatMap(\.attachments)
        do {
            let created = submit
                ? try await repository.submit(request, attachments: attachments)
                : try await repository.saveDraft(request, attachments: attachments)
            form.finishSave(created)
            form = CreateForm()
            await load()
            return true
        } catch {
            form.failSave(error)
            return false
        }
    }
}

extension PengeluaranPresenter.CreateForm {
    func setOptions(accounts: [AccountDTO], branches: [BranchDTO]) {
        self.accounts = accounts
        self.defaultBranchId = (branches.first { $0.isDefault == true } ?? branches.first)?.id
        if cashAccountId == nil { cashAccountId = accounts.first?.id }
    }

    /// A new detached line for the "Tambah Baris" sheet, prefilled with the
    /// header cash account. Not added to `lines` until `commit` is called.
    func newLine() -> PengeluaranPresenter.LineDraft {
        PengeluaranPresenter.LineDraft(accountId: cashAccountId)
    }

    /// Commits an edited draft (called only on "Tambah"). When `replacing` is a
    /// row already in `lines`, its fields are overwritten; otherwise the draft is
    /// appended as a new row.
    func commit(_ draft: PengeluaranPresenter.LineDraft,
                replacing original: PengeluaranPresenter.LineDraft?) {
        if let original, lines.contains(where: { $0.id == original.id }) {
            original.apply(draft)
        } else {
            lines.append(draft)
        }
    }

    func removeLine(_ line: PengeluaranPresenter.LineDraft) {
        lines.removeAll { $0.id == line.id }
    }

    func beginSave() { saveState = .loading }
    func finishSave(_ receipt: CashReceipt) { saveState = .success(receipt) }
    func failSave(_ error: Error) { saveState = .error(error) }
}
