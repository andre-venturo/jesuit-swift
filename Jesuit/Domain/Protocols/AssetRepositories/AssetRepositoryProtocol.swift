//
//  AssetRepositoryProtocol.swift
//  Jesuit
//
//  Abstraction over the wizhub finance assets + asset-categories endpoints
//  (Aset). Plain CRUD — no approval. The branch picker reuses
//  `CashReceiptRepositoryProtocol.fetchBranches()` rather than duplicating it.
//

import Foundation

struct AssetPage: Sendable {
    let assets: [Asset]
    let page: Int
    let totalPages: Int
    let total: Int
}

protocol AssetRepositoryProtocol: Sendable {
    /// Fetches a page of assets. `categoryId` may be a UUID, the literal `"null"`
    /// (the "Lain-lain" bucket), or nil (all). `status` is an `AssetStatus.apiCode`
    /// or nil (all). `search` is a free-text query or nil.
    func fetchAssets(
        page: Int, limit: Int, search: String?, categoryId: String?, status: String?
    ) async throws -> AssetPage

    /// All asset categories, for the form picker and list filter.
    func fetchCategories() async throws -> [AssetCategory]

    /// Loads one asset's full detail (`GET /assets/{id}`).
    func fetchDetail(id: String) async throws -> AssetDTO

    /// Lists an asset's photos (`GET /assets/{id}/attachments`).
    func fetchAttachments(id: String) async throws -> [CashLineAttachment]

    @discardableResult
    func create(_ request: CreateAssetRequest) async throws -> Asset

    @discardableResult
    func update(id: String, request: CreateAssetRequest) async throws -> Asset

    func delete(id: String) async throws

    /// Uploads a photo to an asset (`POST /assets/{id}/attachments`).
    @discardableResult
    func uploadAttachment(id: String, attachment: CashAttachment) async throws -> CashLineAttachment
}
