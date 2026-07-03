//
//  AssetDetailPresenter.swift
//  Jesuit
//
//  Presenter for the Aset detail sheet: loads the full asset and its photos and
//  runs the permission-gated delete. Edit is handled by the create sheet.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class AssetDetailPresenter {
    private let repository: AssetRepositoryProtocol
    private let session: AuthSession

    let id: String

    private(set) var state: AppState<AssetDetail> = .idle
    private(set) var actionState: AppState<Bool> = .idle
    private(set) var photos: [CashLineAttachment] = []

    init(id: String, repository: AssetRepositoryProtocol, session: AuthSession) {
        self.id = id
        self.repository = repository
        self.session = session
    }

    var isLoading: Bool {
        if case .loading = state { return true }
        return false
    }

    var isWorking: Bool {
        if case .loading = actionState { return true }
        return false
    }

    var errorMessage: String? {
        if case .error(let error) = state { return LoginPresenter.message(for: error) }
        return nil
    }

    var actionErrorMessage: String? {
        if case .error(let error) = actionState { return LoginPresenter.message(for: error) }
        return nil
    }

    var detail: AssetDetail? {
        if case .success(let d) = state { return d }
        return nil
    }

    var canEdit: Bool {
        detail != nil && session.can(Permission.assetUpdate)
    }

    var canDelete: Bool {
        detail != nil && session.can(Permission.assetDelete)
    }

    func load() async {
        // `detail` derives from `.success`, so don't blank it while re-fetching
        // (pop-back from the pushed edit screen refires .task). The previous
        // detail stays visible until the fresh one lands.
        if detail == nil { state = .loading }
        do {
            async let photosResult = try? repository.fetchAttachments(id: id)
            let dto = try await repository.fetchDetail(id: id)
            photos = await photosResult ?? []
            state = .success(AssetDetail(dto: dto))
        } catch {
            state = .error(error)
        }
    }

    @discardableResult
    func delete() async -> Bool {
        actionState = .loading
        do {
            try await repository.delete(id: id)
            actionState = .success(true)
            return true
        } catch {
            actionState = .error(error)
            return false
        }
    }
}
