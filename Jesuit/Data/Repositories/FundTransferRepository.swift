//
//  FundTransferRepository.swift
//  Jesuit
//
//  Concrete implementation of the finance fund-transfers endpoint
//  (/finance/v1/fund-transfers). Mirrors `CashReceiptRepository` minus the
//  journal-line plumbing — a transfer is a single header.
//

import Foundation

struct FundTransferRepository: FundTransferRepositoryProtocol {
    private let network: NetworkServiceProtocol

    init(network: NetworkServiceProtocol) {
        self.network = network
    }

    // MARK: - List

    func fetchTransfers(page: Int, limit: Int, dateFrom: String?, dateTo: String?) async throws -> FundTransferPage {
        var params = ["page": String(page), "limit": String(limit)]
        if let dateFrom, !dateFrom.isEmpty { params["date_from"] = dateFrom }
        if let dateTo, !dateTo.isEmpty { params["date_to"] = dateTo }
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.fundTransfers,
            method: .get,
            parameters: params
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: FundTransferListResponse.self
        )
        let transfers = (response.data ?? []).map(FundTransfer.init(dto:))
        let pagination = response.meta?.pagination
        return FundTransferPage(
            transfers: transfers,
            counts: response.meta?.counts,
            page: pagination?.page ?? page,
            totalPages: pagination?.totalPages ?? 0,
            total: pagination?.total ?? transfers.count
        )
    }

    // MARK: - Create

    @discardableResult
    func saveDraft(_ request: CreateFundTransferRequest) async throws -> FundTransfer {
        try await post(path: AppURLConstants.Finance.fundTransfers, request: request)
    }

    @discardableResult
    func submit(_ request: CreateFundTransferRequest) async throws -> FundTransfer {
        try await post(path: AppURLConstants.Finance.fundTransfersSubmit, request: request)
    }

    private func post(path: String, request: CreateFundTransferRequest) async throws -> FundTransfer {
        let endpoint = Endpoint(baseURL: AppURLConstants.financeBaseURL, path: path, method: .post)
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: request,
            responseType: FundTransferDetailResponse.self
        )
        guard let dto = response.data else { throw NetworkError.noData }
        return FundTransfer(dto: dto)
    }

    // MARK: - Detail / update / lifecycle

    func fetchDetail(id: String) async throws -> FundTransferDTO {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.fundTransfer(id),
            method: .get
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: FundTransferDetailResponse.self
        )
        guard let dto = response.data else { throw NetworkError.noData }
        return dto
    }

    @discardableResult
    func update(id: String, request: CreateFundTransferRequest) async throws -> FundTransferDTO {
        try await mutate(path: AppURLConstants.Finance.fundTransfer(id), method: .put, body: request)
    }

    @discardableResult
    func updateAndSubmit(id: String, request: CreateFundTransferRequest) async throws -> FundTransferDTO {
        // BE's `POST /{id}/submit` replaces all header fields, so it takes the
        // full create payload (same body as PUT).
        try await mutate(path: "\(AppURLConstants.Finance.fundTransfer(id))/submit", method: .post, body: request)
    }

    @discardableResult
    func approve(id: String, comment: String) async throws -> FundTransferDTO {
        try await mutate(
            path: AppURLConstants.Finance.fundTransferApprove(id),
            method: .post,
            body: ApproveRequest(comment: comment)
        )
    }

    @discardableResult
    func reject(id: String, reason: String) async throws -> FundTransferDTO {
        try await mutate(
            path: AppURLConstants.Finance.fundTransferReject(id),
            method: .post,
            body: RejectRequest(reason: reason)
        )
    }

    private func mutate<Body: Encodable & Sendable>(
        path: String, method: HTTPMethod, body: Body
    ) async throws -> FundTransferDTO {
        let endpoint = Endpoint(baseURL: AppURLConstants.financeBaseURL, path: path, method: method)
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: body,
            responseType: FundTransferDetailResponse.self
        )
        guard let dto = response.data else { throw NetworkError.noData }
        return dto
    }

    func delete(id: String) async throws {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.fundTransfer(id),
            method: .delete
        )
        _ = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: FundTransferDetailResponse.self
        )
    }

    // MARK: - Attachments

    /// Envelope for the attachment upload: `{ data: CashAttachmentDTO, message }`.
    private nonisolated struct AttachmentResponse: Codable, Sendable {
        let data: CashAttachmentDTO?
        let message: String?
    }

    @discardableResult
    func uploadAttachment(id: String, attachment: CashAttachment) async throws -> CashLineAttachment {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.fundTransferAttachments(id),
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

    // MARK: - Activity log (Riwayat tab)

    func fetchActivity(reffId: String) async throws -> [AuditLogDTO] {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.baseURL,
            path: AppURLConstants.Core.auditLogs,
            method: .get,
            parameters: [
                "reff_type": "finance.fund_transfers",
                "reff_id": reffId,
                "limit": "100"
            ]
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: PaginatedResponse<AuditLogDTO>.self
        )
        return response.data ?? []
    }
}
