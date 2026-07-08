//
//  MasterAkunPresenter.swift
//  Jesuit
//
//  Presenter for the Master Akun (chart of accounts) management screen.
//  Mirrors ContactPresenter, minus pagination: the verified /accounts endpoint
//  returns the whole chart in one `{ data: { accounts, total } }` payload.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class MasterAkunPresenter {
    private let repository: AccountRepositoryProtocol

    /// Status filter (chosen in the filter sheet).
    enum StatusFilter: String, CaseIterable, Identifiable, Sendable {
        case all = "Semua"
        case active = "Aktif"
        case inactive = "Nonaktif"
        var id: String { rawValue }
    }

    private(set) var accounts: [ChartAccount] = []
    private(set) var state: AppState<[ChartAccount]> = .idle

    /// Type chip selection (nil == Semua).
    var typeFilter: AccountType?
    var statusFilter: StatusFilter = .all
    var searchText: String = ""

    init(repository: AccountRepositoryProtocol) {
        self.repository = repository
    }

    // MARK: - Derived list

    /// Accounts after the type chip, status filter and search.
    var filtered: [ChartAccount] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return accounts
            .filter { typeFilter == nil || $0.type == typeFilter }
            .filter { account in
                switch statusFilter {
                case .all:      return true
                case .active:   return account.isActive
                case .inactive: return !account.isActive
                }
            }
            .filter { query.isEmpty || $0.name.lowercased().contains(query)
                || ($0.code?.lowercased().contains(query) ?? false) }
    }

    /// `filtered` grouped by type in `AccountType.allCases` order; accounts with
    /// an unknown/missing type land in a trailing nil ("Lainnya") bucket. Rows
    /// sort by code then name (COA convention).
    var sections: [(type: AccountType?, rows: [ChartAccount])] {
        let rows = filtered.sorted {
            let l = $0.code ?? "", r = $1.code ?? ""
            return l == r
                ? $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                : l.localizedStandardCompare(r) == .orderedAscending
        }
        var buckets: [(type: AccountType?, rows: [ChartAccount])] = []
        for type in AccountType.allCases {
            let matched = rows.filter { $0.type == type }
            if !matched.isEmpty { buckets.append((type, matched)) }
        }
        let unknown = rows.filter { $0.type == nil }
        if !unknown.isEmpty { buckets.append((nil, unknown)) }
        return buckets
    }

    var hasActiveFilters: Bool { typeFilter != nil || statusFilter != .all }

    var isLoading: Bool {
        // .idle counts as loading: load() runs on appear, so before it flips to
        // .loading the screen must show the spinner, not flash the empty state.
        switch state {
        case .idle, .loading: return true
        default: return false
        }
    }

    var errorMessage: String? {
        if case .error(let error) = state {
            return LoginPresenter.message(for: error)
        }
        return nil
    }

    // MARK: - Form options

    /// Distinct sub-types present in the chart, as (raw id, display label)
    /// pairs — the server's data is the source of truth for this vocabulary
    /// (verified values: cash_bank "Cash & Bank", account_receivable
    /// "Account Receivable"). The form sends the raw id.
    var subTypeOptions: [(id: String, label: String)] {
        var seen = Set<String>()
        var options: [(id: String, label: String)] = []
        for account in accounts {
            guard let raw = account.subType, !raw.isEmpty, !seen.contains(raw) else { continue }
            seen.insert(raw)
            options.append((id: raw, label: account.subTypeLabel ?? raw))
        }
        return options.sorted { $0.label < $1.label }
    }

    /// Header accounts of the given type, offered as parent options.
    func parentOptions(for type: AccountType?) -> [ChartAccount] {
        accounts.filter { $0.isHeader && (type == nil || $0.type == type) }
    }

    /// Resolves an account's parent name for the detail page.
    func accountName(for id: String?) -> String? {
        id.flatMap { pid in accounts.first { $0.id == pid }?.name }
    }

    /// The current version of an account after edits (detail page re-reads it).
    func account(id: String) -> ChartAccount? {
        accounts.first { $0.id == id }
    }

    // MARK: - Load

    /// Fetches the whole chart (the endpoint is not paginated).
    func load() async {
        // Keep the current list visible while re-fetching (pop-back refires the
        // screen's .task). Spinner only on first load.
        state = accounts.isEmpty ? .loading : .refreshing
        do {
            let all = try await repository.fetchAccounts()
            accounts = all
            state = all.isEmpty ? .empty : .success(all)
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            accounts = []
            state = .error(error)
        }
    }

    // MARK: - Create / edit form

    /// Editable form backing the create/edit account page.
    @Observable
    @MainActor
    final class CreateForm {
        var name = ""
        var code = ""
        /// `AccountType.rawValue`; required.
        var typeId = ""
        var subType = ""
        var currencyCode = "IDR"
        var parentId = ""
        var descriptionText = ""
        var isActive = true

        /// Non-nil when editing an existing account (PUT instead of POST).
        var editId: String?
        var errorMessage: String?

        var isEditing: Bool { editId != nil }

        var isValid: Bool {
            !name.trimmingCharacters(in: .whitespaces).isEmpty && !typeId.isEmpty
        }

        func reset() {
            name = ""; code = ""; typeId = ""; subType = ""
            currencyCode = "IDR"; parentId = ""; descriptionText = ""
            isActive = true; editId = nil; errorMessage = nil
        }

        /// Seeds the form from an existing account for editing. Preserves a raw
        /// type/sub-type value even when it's outside the known vocabulary.
        func seed(from account: ChartAccount) {
            editId = account.id
            name = account.name
            code = account.code ?? ""
            typeId = account.typeRaw ?? account.type?.rawValue ?? ""
            subType = account.subType ?? ""
            currencyCode = account.currencyCode ?? "IDR"
            parentId = account.parentId ?? ""
            descriptionText = account.description ?? ""
            isActive = account.isActive
            errorMessage = nil
        }

        /// Builds the API request, trimming and nil-ing empty optionals.
        /// Never sends `is_header` — creating headers stays on the web app (v1).
        func makeRequest() -> SaveAccountRequest {
            func clean(_ s: String) -> String? {
                let t = s.trimmingCharacters(in: .whitespaces)
                return t.isEmpty ? nil : t
            }
            return SaveAccountRequest(
                name: name.trimmingCharacters(in: .whitespaces),
                accountType: typeId,
                code: clean(code),
                accountSubType: clean(subType),
                currencyCode: clean(currencyCode),
                description: clean(descriptionText),
                parentId: clean(parentId),
                isActive: isActive
            )
        }
    }

    let form = CreateForm()
    private(set) var saveState: AppState<ChartAccount> = .idle

    var isSaving: Bool {
        if case .loading = saveState { return true }
        return false
    }

    /// Resets the form for a brand-new account (clears any prior edit).
    func startCreate() {
        form.reset()
    }

    /// Seeds the form from an existing account for editing (PUT on save).
    func startEditing(_ account: ChartAccount) {
        form.seed(from: account)
    }

    /// Submits the form: PUT when editing, POST otherwise. Returns `true` on
    /// success (caller dismisses; the list is reloaded here).
    func saveAccount() async -> Bool {
        form.errorMessage = nil
        guard form.isValid else {
            form.errorMessage = "Nama dan tipe akun wajib diisi."
            return false
        }
        saveState = .loading
        do {
            let account: ChartAccount
            if let editId = form.editId {
                account = try await repository.update(id: editId, request: form.makeRequest())
            } else {
                account = try await repository.create(form.makeRequest())
            }
            saveState = .success(account)
            form.reset()
            await load()
            return true
        } catch {
            saveState = .error(error)
            form.errorMessage = LoginPresenter.message(for: error)
            return false
        }
    }

    // MARK: - Delete

    /// Id of the account currently being deleted, for button progress.
    private(set) var deletingId: String?
    /// Delete failure surfaced by the detail page (e.g. account already used
    /// by transactions — the server rejects and we show its message).
    private(set) var deleteError: String?

    /// Deletes an account and reloads the list. Returns `true` on success.
    @discardableResult
    func deleteAccount(id: String) async -> Bool {
        guard deletingId == nil else { return false }
        deletingId = id
        deleteError = nil
        defer { deletingId = nil }
        do {
            try await repository.delete(id: id)
            await load()
            return true
        } catch {
            deleteError = LoginPresenter.message(for: error)
            return false
        }
    }
}
