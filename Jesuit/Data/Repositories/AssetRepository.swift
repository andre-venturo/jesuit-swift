//
//  AssetRepository.swift
//  Jesuit
//
//  Concrete implementation of the finance assets + asset-categories endpoints
//  (/finance/v1/assets, /finance/v1/asset-categories). Plain CRUD.
//

import Foundation

struct AssetRepository: AssetRepositoryProtocol {
    private let network: NetworkServiceProtocol

    init(network: NetworkServiceProtocol) {
        self.network = network
    }

    // MARK: - List

    func fetchAssets(
        page: Int, limit: Int, search: String?, categoryId: String?, status: String?
    ) async throws -> AssetPage {
        var params = ["page": String(page), "limit": String(limit)]
        if let search, !search.isEmpty { params["search"] = search }
        if let categoryId, !categoryId.isEmpty { params["category_id"] = categoryId }
        if let status, !status.isEmpty { params["status"] = status }

        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.assets,
            method: .get,
            parameters: params
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: AssetListResponse.self
        )
        let assets = (response.data ?? []).map(Asset.init(dto:))
        let pagination = response.meta?.pagination
        return AssetPage(
            assets: assets,
            page: pagination?.page ?? page,
            totalPages: pagination?.totalPages ?? 0,
            total: pagination?.total ?? assets.count
        )
    }

    // MARK: - Categories

    func fetchCategories() async throws -> [AssetCategory] {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.assetCategories,
            method: .get,
            parameters: ["limit": "200"]
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: AssetCategoriesResponse.self
        )
        return (response.data ?? []).map(AssetCategory.init(dto:))
    }

    // MARK: - Detail

    func fetchDetail(id: String) async throws -> AssetDTO {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.asset(id),
            method: .get
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: AssetDetailResponse.self
        )
        guard let dto = response.data else { throw NetworkError.noData }
        return dto
    }

    func fetchAttachments(id: String) async throws -> [CashLineAttachment] {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.assetAttachments(id),
            method: .get
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: AssetAttachmentsResponse.self
        )
        return (response.data ?? []).compactMap { dto in
            guard let url = dto.fileUrl, !url.isEmpty else { return nil }
            return CashLineAttachment(
                id: dto.id,
                fileName: dto.fileName ?? "Foto",
                fileUrl: url,
                fileSize: dto.fileSize ?? 0,
                mimeType: dto.mimeType ?? ""
            )
        }
    }

    // MARK: - Create / update / delete

    @discardableResult
    func create(_ request: CreateAssetRequest) async throws -> Asset {
        try await write(path: AppURLConstants.Finance.assets, method: .post, request: request)
    }

    @discardableResult
    func update(id: String, request: CreateAssetRequest) async throws -> Asset {
        try await write(path: AppURLConstants.Finance.asset(id), method: .put, request: request)
    }

    private func write(path: String, method: HTTPMethod, request: CreateAssetRequest) async throws -> Asset {
        let endpoint = Endpoint(baseURL: AppURLConstants.financeBaseURL, path: path, method: method)
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: request,
            responseType: AssetDetailResponse.self
        )
        guard let dto = response.data else { throw NetworkError.noData }
        return Asset(dto: dto)
    }

    func delete(id: String) async throws {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.asset(id),
            method: .delete
        )
        _ = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: AssetDetailResponse.self
        )
    }

    // MARK: - Attachments

    private nonisolated struct AttachmentResponse: Codable, Sendable {
        let data: CashAttachmentDTO?
        let message: String?
    }

    @discardableResult
    func uploadAttachment(id: String, attachment: CashAttachment) async throws -> CashLineAttachment {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.assetAttachments(id),
            method: .post
        )
        let file = MultipartFile(
            field: "file",
            filename: attachment.filename,
            mimeType: attachment.mimeType,
            data: attachment.data
        )
        let response = try await network.requestMultipartDecoded(
            endpoint: endpoint,
            textFields: [],
            files: [file],
            responseType: AttachmentResponse.self
        )
        guard let dto = response.data, let url = dto.fileUrl, !url.isEmpty else {
            throw NetworkError.noData
        }
        return CashLineAttachment(
            id: dto.id,
            fileName: dto.fileName ?? attachment.filename,
            fileUrl: url,
            fileSize: dto.fileSize ?? attachment.data.count,
            mimeType: dto.mimeType ?? attachment.mimeType
        )
    }
}
