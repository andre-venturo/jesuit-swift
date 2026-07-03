//
//  AssetPresenter.swift
//  Jesuit
//
//  Presenter for the Aset (assets) list + create/edit form. Category and status
//  are server-side filters (reload on change); search is client-side over the
//  loaded pages. Branch options reuse the cash-receipt repository.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class AssetPresenter {
    private let repository: AssetRepositoryProtocol
    /// Reused for the branch picker (the asset endpoint has none of its own).
    private let lookups: CashReceiptRepositoryProtocol

    /// Sentinel category id for the "Lain-lain" (uncategorised) bucket.
    static let othersId = "null"

    var searchText: String = ""
    /// Category filter: nil = all, `othersId` = Lain-lain, else a category UUID.
    private(set) var categoryFilterId: String?
    private(set) var statusFilter: AssetStatus?

    private(set) var categories: [AssetCategory] = []
    private(set) var assets: [Asset] = []
    private(set) var state: AppState<[Asset]> = .idle

    var attachmentWarning: String?
    private(set) var loadMoreFailed = false

    private let pageSize = 10
    private var page = 1
    private var totalPages = 1

    init(repository: AssetRepositoryProtocol, lookups: CashReceiptRepositoryProtocol) {
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

    // MARK: - Filters

    var categoryLabel: String {
        guard let id = categoryFilterId else { return "Semua" }
        if id == Self.othersId { return "Lain-lain" }
        return categories.first { $0.id == id }?.name ?? "Semua"
    }

    /// Inline quick chips: "Semua" plus the first two categories.
    var categoryChips: [String] {
        ["Semua"] + categories.prefix(2).map(\.name)
    }

    /// Full category options for the filter sheet (`id == ""` → Semua).
    var categoryFilterOptions: [FilterOption] {
        [FilterOption(id: "", label: "Semua", count: assets.count)]
            + categories.map { FilterOption(id: $0.id, label: $0.name, count: $0.assetCount) }
            + [FilterOption(id: Self.othersId, label: "Lain-lain", count: 0)]
    }

    var statusFilterOptions: [FilterOption] {
        [FilterOption(id: "", label: "Semua", count: 0)]
            + AssetStatus.allCases.map { FilterOption(id: $0.apiCode, label: $0.rawValue, count: 0) }
    }

    func selectCategory(label: String) {
        if label == "Semua" { categoryFilterId = nil }
        else if label == "Lain-lain" { categoryFilterId = Self.othersId }
        else { categoryFilterId = categories.first { $0.name == label }?.id }
        Task { await load() }
    }

    /// Applies both filters at once (from the combined filter sheet) with a single
    /// reload. `categoryId`/`status` use `""` for "Semua". `status` is an
    /// `AssetStatus.apiCode`.
    func applyFilters(categoryId: String, status: String) {
        categoryFilterId = categoryId.isEmpty ? nil : categoryId
        statusFilter = AssetStatus.allCases.first { $0.apiCode == status }
        Task { await load() }
    }

    /// Assets after the client-side search query (category/status are server-side).
    var filtered: [Asset] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        return assets.filter { query.isEmpty
            || $0.name.lowercased().contains(query)
            || $0.code.lowercased().contains(query) }
    }

    // MARK: - Load

    func loadCategories() async {
        if let cats = try? await repository.fetchCategories() { categories = cats }
    }

    func load() async {
        // Keep showing the current grid while re-fetching (pop-back refires the
        // screen's .task — a NavigationStack detaches the root during a push, so
        // its .task reruns on return). Only blank to a spinner on first load.
        state = assets.isEmpty ? .loading : .refreshing
        do {
            let result = try await repository.fetchAssets(
                page: 1, limit: pageSize, search: nil,
                categoryId: categoryFilterId, status: statusFilter?.apiCode
            )
            assets = result.assets
            page = 1
            totalPages = result.totalPages
            state = result.assets.isEmpty ? .empty : .success(result.assets)
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled { return }
            assets = []
            state = .error(error)
        }
    }

    func loadMore() async {
        guard canLoadMore, case .success = state else { return }
        state = .loadmore
        loadMoreFailed = false
        do {
            let result = try await repository.fetchAssets(
                page: page + 1, limit: pageSize, search: nil,
                categoryId: categoryFilterId, status: statusFilter?.apiCode
            )
            page += 1
            totalPages = result.totalPages
            let seen = Set(assets.map(\.id))
            assets += result.assets.filter { !seen.contains($0.id) }
        } catch {
            loadMoreFailed = true
        }
        state = .success(assets)
    }

    // MARK: - Create / edit form

    @Observable
    @MainActor
    final class CreateForm {
        var name = ""
        var categoryId: String?       // nil → Lain-lain
        var branchId: String?
        var purchaseValueText = ""    // IDR digits
        var quantityText = "1"
        var purchaseDate: Date = .now
        var hasPurchaseDate = false
        var location = ""
        var note = ""

        var attachments: [CashAttachment] = []
        var existingAttachments: [CashLineAttachment] = []

        // Hidden fields — seeded from the existing asset on edit, defaults on create.
        var startUseDate: String?
        var assetAgeYear: Int?
        var assetAgeMonth: Int?
        var isIntangible = false
        var depreciationMethod = "straight-line"
        var salvageValue: Double = 0
        var depreciationRate: Double?

        private(set) var editId: String?
        private(set) var categories: [AssetCategory] = []
        private(set) var branches: [BranchDTO] = []
        private(set) var saveState: AppState<Bool> = .idle

        /// Sentinel id for the "Lain-lain" option in the category picker.
        static let othersOptionId = "__others__"

        var isEditing: Bool { editId != nil }
        var purchaseValue: Double { Double(purchaseValueText) ?? 0 }
        var quantity: Int { max(1, Int(quantityText) ?? 1) }

        var isSaving: Bool {
            if case .loading = saveState { return true }
            return false
        }

        var errorMessage: String? {
            if case .error(let error) = saveState { return LoginPresenter.message(for: error) }
            return nil
        }

        var canSave: Bool {
            !name.trimmingCharacters(in: .whitespaces).isEmpty
                && branchId != nil
                && purchaseValue > 0
                && !isSaving
        }

        func categoryName(for id: String?) -> String? {
            categories.first { $0.id == id }?.name
        }

        func setOptions(categories: [AssetCategory], branches: [BranchDTO]) {
            self.categories = categories
            self.branches = branches
            if branchId == nil {
                branchId = (branches.first { $0.isDefault == true } ?? branches.first)?.id
            }
        }

        func seed(from detail: AssetDetail) {
            editId = detail.id
            name = detail.name
            categoryId = detail.categoryId
            branchId = detail.branchId
            purchaseValueText = String(Int(detail.purchaseValue))
            quantityText = String(detail.quantity)
            if let date = detail.purchaseDate { purchaseDate = date; hasPurchaseDate = true }
            location = detail.location
            note = detail.note
            startUseDate = Self.ymd(detail.startUseDate)
            assetAgeYear = detail.assetAgeYear
            assetAgeMonth = detail.assetAgeMonth
            isIntangible = detail.isIntangible
            depreciationMethod = detail.depreciationMethod
            salvageValue = detail.salvageValue
            depreciationRate = detail.depreciationRate
        }

        func makeRequest() -> CreateAssetRequest {
            func clean(_ s: String) -> String? {
                let t = s.trimmingCharacters(in: .whitespaces)
                return t.isEmpty ? nil : t
            }
            return CreateAssetRequest(
                assetName: name.trimmingCharacters(in: .whitespaces),
                categoryId: categoryId,
                branchId: branchId ?? "",
                purchaseValue: purchaseValue,
                quantity: quantity,
                purchaseDate: hasPurchaseDate ? Self.ymd(purchaseDate) : nil,
                location: clean(location),
                note: clean(note),
                startUseDate: startUseDate,
                assetAgeYear: assetAgeYear,
                assetAgeMonth: assetAgeMonth,
                isIntangible: isIntangible,
                depreciationMethod: depreciationMethod,
                salvageValue: salvageValue,
                depreciationRate: depreciationRate
            )
        }

        static func ymd(_ date: Date?) -> String? {
            guard let date else { return nil }
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = "yyyy-MM-dd"
            return df.string(from: date)
        }

        func beginSave() { saveState = .loading }
        func finishSave() { saveState = .success(true) }
        func failSave(_ error: Error) { saveState = .error(error) }
    }

    var form = CreateForm()

    func startCreate() { form = CreateForm() }

    func startEditing(_ detail: AssetDetail) {
        let f = CreateForm()
        f.seed(from: detail)
        form = f
    }

    /// Loads the category + branch pickers (and, when editing, the asset's photos).
    func loadFormOptions() async {
        async let categoriesResult = try? repository.fetchCategories()
        async let branchesResult = try? lookups.fetchBranches()
        let categories = await categoriesResult ?? []
        let branches = await branchesResult ?? []
        form.setOptions(categories: categories, branches: branches)
        if let editId = form.editId, form.existingAttachments.isEmpty,
           let existing = try? await repository.fetchAttachments(id: editId) {
            form.existingAttachments = existing
        }
    }

    /// Saves the form: create or update, then uploads any pending photos.
    func save() async -> Bool {
        guard form.canSave else { return false }
        form.beginSave()
        let request = form.makeRequest()
        attachmentWarning = nil
        do {
            let savedId: String
            if let editId = form.editId {
                let saved = try await repository.update(id: editId, request: request)
                savedId = saved.id
            } else {
                let saved = try await repository.create(request)
                savedId = saved.id
            }
            let failed = await uploadAttachments(id: savedId)
            if failed > 0 {
                attachmentWarning = "Aset tersimpan, tetapi \(failed) foto gagal diunggah. Buka kembali untuk mencoba lagi."
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
