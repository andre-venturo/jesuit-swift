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
        case unpaid = "Belum Lunas"
        case all = "Semua"
        var id: String { rawValue }
    }

    /// Sort order for the list (toggled by the sort button).
    enum SortOrder: Sendable { case nameAsc, nameDesc }

    private(set) var contacts: [Contact] = []
    private(set) var state: AppState<[Contact]> = .idle

    var filter: Filter = .all
    var sortOrder: SortOrder = .nameAsc
    var searchText: String = ""

    private let pageSize = 25

    init(contactRepository: ContactRepositoryProtocol) {
        self.contactRepository = contactRepository
    }

    /// Contacts after applying the active filter chip, search and sort.
    var filtered: [Contact] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return contacts
            .filter { contact in
                switch filter {
                case .all:    return true
                case .active: return true   // all seeded contacts are active
                case .unpaid: return contact.receivables > 0
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

    func toggleSort() {
        sortOrder = sortOrder == .nameAsc ? .nameDesc : .nameAsc
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

    /// Loads the first page of contacts from the finance API.
    func load() async {
        state = .loading
        do {
            let page = try await contactRepository.fetchContacts(page: 1, limit: pageSize)
            contacts = page.contacts
            state = page.contacts.isEmpty ? .empty : .success(page.contacts)
        } catch {
            contacts = []
            state = .error(error)
        }
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
