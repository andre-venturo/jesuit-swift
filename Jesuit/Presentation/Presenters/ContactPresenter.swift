//
//  ContactPresenter.swift
//  Jesuit
//
//  Presenter for the Kontak (contacts) screen.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class ContactPresenter {
    private let contactRepository: ContactRepositoryProtocol

    /// Top filter chip selection.
    enum Filter: String, CaseIterable, Identifiable, Sendable {
        case active = "Aktif"
        case inactive = "Nonaktif"
        case all = "Semua"
        var id: String { rawValue }
    }

    /// Sort order for the list (chosen in the Urutkan sheet).
    enum SortOrder: String, CaseIterable, Identifiable, Sendable {
        case nameAsc  = "Nama (A-Z)"
        case nameDesc = "Nama (Z-A)"
        var id: String { rawValue }
    }

    private(set) var contacts: [Contact] = []
    private(set) var state: AppState<[Contact]> = .idle

    /// True when the last `loadMore()` page fetch failed, so the list can offer a retry.
    private(set) var loadMoreFailed = false

    var filter: Filter = .all
    var sortOrder: SortOrder = .nameAsc
    var searchText: String = ""

    private let pageSize = 10
    private var page = 1
    private var totalPages = 1

    init(contactRepository: ContactRepositoryProtocol) {
        self.contactRepository = contactRepository
    }

    /// Contacts after applying the active filter chip, search and sort.
    var filtered: [Contact] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return contacts
            .filter { contact in
                switch filter {
                case .all:      return true
                case .active:   return contact.isActive
                case .inactive: return !contact.isActive
                }
            }
            .filter { query.isEmpty || $0.name.lowercased().contains(query)
                || $0.company.lowercased().contains(query) }
            .sorted { lhs, rhs in
                switch sortOrder {
                case .nameAsc:  return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
                case .nameDesc: return lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedDescending
                }
            }
    }

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

    var isLoadingMore: Bool {
        if case .loadmore = state { return true }
        return false
    }

    /// More server pages remain (load-more only pages the unfiltered list).
    var canLoadMore: Bool { page < totalPages }

    /// Loads the first page of contacts from the finance API.
    func load() async {
        // Keep the current list visible while re-fetching (pop-back refires the
        // screen's .task). Spinner only on first load.
        state = contacts.isEmpty ? .loading : .refreshing
        do {
            let result = try await contactRepository.fetchContacts(page: 1, limit: pageSize)
            contacts = result.contacts
            page = 1
            totalPages = result.totalPages
            state = result.contacts.isEmpty ? .empty : .success(result.contacts)
        } catch {
            // TabView appear/disappear churn cancels the .task mid-load; that's not
            // a real failure, so leave .loading for the immediate re-run.
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            contacts = []
            state = .error(error)
        }
    }

    /// Appends the next page; no-op while already paging or at the last page.
    func loadMore() async {
        guard canLoadMore, case .success = state else { return }
        state = .loadmore
        loadMoreFailed = false
        do {
            let result = try await contactRepository.fetchContacts(page: page + 1, limit: pageSize)
            page += 1
            totalPages = result.totalPages
            let seen = Set(contacts.map(\.id))
            contacts += result.contacts.filter { !seen.contains($0.id) }
        } catch {
            // Keep what we have, but tell the user the next page failed so they can retry.
            loadMoreFailed = true
        }
        state = .success(contacts)
    }

    // MARK: - Create contact

    /// Editable form backing the "Kontak Baru" create sheet.
    @Observable
    @MainActor
    final class CreateForm {
        var name = ""
        var categoryId = ""
        var email = ""
        var phone = ""
        var address = ""
        var picName = ""
        var picPosition = ""
        var isActive = true

        /// Non-nil when editing an existing contact (PUT instead of create).
        var editId: String?

        var categories: [ContactCategoryDTO] = []
        var errorMessage: String?

        var isEditing: Bool { editId != nil }

        /// Display name of the picked category for the menu label.
        var categoryName: String {
            categories.first { $0.id == categoryId }?.name ?? "Pilih kategori"
        }

        var isValid: Bool {
            !name.trimmingCharacters(in: .whitespaces).isEmpty && !categoryId.isEmpty
        }

        func reset() {
            name = ""; categoryId = ""; email = ""; phone = ""
            address = ""; picName = ""; picPosition = ""; isActive = true
            editId = nil; errorMessage = nil
        }

        /// Seeds the form from an existing contact for editing.
        func seed(from contact: Contact) {
            editId = contact.id
            name = contact.name
            categoryId = contact.categoryId ?? ""
            email = contact.email ?? ""
            phone = contact.phone ?? ""
            address = contact.address ?? ""
            picName = contact.picName ?? ""
            picPosition = contact.picPosition ?? ""
            isActive = contact.isActive
            errorMessage = nil
        }

        /// Builds the API request, trimming and nil-ing empty optionals.
        func makeRequest() -> CreateContactRequest {
            func clean(_ s: String) -> String? {
                let t = s.trimmingCharacters(in: .whitespaces)
                return t.isEmpty ? nil : t
            }
            return CreateContactRequest(
                name: name.trimmingCharacters(in: .whitespaces),
                categoryId: categoryId,
                email: clean(email),
                phone: clean(phone),
                address: clean(address),
                picName: clean(picName),
                picPosition: clean(picPosition),
                isActive: isActive
            )
        }
    }

    let form = CreateForm()
    private(set) var saveState: AppState<Contact> = .idle

    var isSaving: Bool {
        if case .loading = saveState { return true }
        return false
    }

    /// Resets the form for a brand-new contact (clears any prior edit).
    func startCreate() {
        form.reset()
    }

    /// Seeds the form from an existing contact for editing (PUT on save).
    func startEditing(_ contact: Contact) {
        form.seed(from: contact)
    }

    /// Loads category options for the form. Defaults the selection to the first
    /// category only when creating (an edit keeps the seeded category).
    func loadCategories() async {
        if let categories = try? await contactRepository.fetchCategories() {
            form.categories = categories
            if form.categoryId.isEmpty {
                form.categoryId = categories.first(where: { $0.isDefault == true })?.id
                    ?? categories.first?.id ?? ""
            }
        }
    }

    /// Submits the form: PUT when editing, POST otherwise. Returns `true` on
    /// success (caller dismisses + reloads the list).
    func saveContact() async -> Bool {
        form.errorMessage = nil
        guard form.isValid else {
            form.errorMessage = "Nama dan kategori wajib diisi."
            return false
        }
        saveState = .loading
        do {
            let contact: Contact
            if let editId = form.editId {
                contact = try await contactRepository.updateContact(id: editId, request: form.makeRequest())
            } else {
                contact = try await contactRepository.createContact(form.makeRequest())
            }
            saveState = .success(contact)
            form.reset()
            await load()
            return true
        } catch {
            saveState = .error(error)
            form.errorMessage = LoginPresenter.message(for: error)
            return false
        }
    }

    // MARK: - Delete contact

    /// Id of the contact currently being deleted, for per-row progress.
    private(set) var deletingId: String?

    /// Deletes a contact and reloads the list. Returns `true` on success.
    @discardableResult
    func deleteContact(id: String) async -> Bool {
        guard deletingId == nil else { return false }
        deletingId = id
        defer { deletingId = nil }
        do {
            try await contactRepository.deleteContact(id: id)
            await load()
            return true
        } catch {
            form.errorMessage = LoginPresenter.message(for: error)
            return false
        }
    }
}
