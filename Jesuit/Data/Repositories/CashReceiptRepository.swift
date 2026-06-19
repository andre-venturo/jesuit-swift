//
//  CashReceiptRepository.swift
//  Jesuit
//
//  Concrete implementation of the finance cash-receipts endpoint
//  (GET /finance/v1/cash-transactions?transaction_type=receipt).
//

import Foundation

struct CashReceiptRepository: CashReceiptRepositoryProtocol {
    private let network: NetworkServiceProtocol

    init(network: NetworkServiceProtocol) {
        self.network = network
    }

    /// Envelope for the cash-transactions list. Mirrors `PaginatedResponse` but
    /// with the richer `meta.counts` this endpoint returns
    /// (`all/draft/posted/rejected/waiting`).
    private nonisolated struct Response: Codable, Sendable {
        let data: [CashTransactionDTO]?
        let message: String?
        let meta: Meta?

        nonisolated struct Meta: Codable, Sendable {
            let pagination: PaginatedResponse<CashTransactionDTO>.Pagination?
            let counts: CashTransactionCounts?
        }
    }

    func fetchReceipts(page: Int, limit: Int) async throws -> CashReceiptPage {
        try await fetch(transactionType: "receipt", page: page, limit: limit)
    }

    func fetchDisbursements(page: Int, limit: Int) async throws -> CashReceiptPage {
        try await fetch(transactionType: "disbursement", page: page, limit: limit)
    }

    /// Shared fetch for both receipt and disbursement transaction types; they
    /// share the response envelope, DTO and per-status counts.
    private func fetch(transactionType: String, page: Int, limit: Int) async throws -> CashReceiptPage {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.cashTransactions,
            method: .get,
            parameters: [
                "page": String(page),
                "limit": String(limit),
                "transaction_type": transactionType
            ]
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: Response.self
        )

        let receipts = (response.data ?? []).map(CashReceipt.init(dto:))
        let pagination = response.meta?.pagination
        return CashReceiptPage(
            receipts: receipts,
            counts: response.meta?.counts,
            page: pagination?.page ?? page,
            totalPages: pagination?.totalPages ?? 0,
            total: pagination?.total ?? receipts.count
        )
    }

    // MARK: - Create

    /// Envelope for `submit`: `{ data: CashTransactionDTO, message }`.
    private nonisolated struct SubmitResponse: Codable, Sendable {
        let data: CashTransactionDTO?
        let message: String?
    }

    @discardableResult
    func submit(_ request: CashTransactionRequest, attachments: [CashAttachment]) async throws -> CashReceipt {
        try await post(path: AppURLConstants.Finance.cashTransactionsSubmit, request: request, attachments: attachments)
    }

    @discardableResult
    func saveDraft(_ request: CashTransactionRequest, attachments: [CashAttachment]) async throws -> CashReceipt {
        // Same payload as submit, un-suffixed collection path (the web client's
        // "Simpan Draft" posts to /cash-transactions).
        try await post(path: AppURLConstants.Finance.cashTransactions, request: request, attachments: attachments)
    }

    private func post(
        path: String,
        request: CashTransactionRequest,
        attachments: [CashAttachment]
    ) async throws -> CashReceipt {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: path,
            method: .post
        )

        let response: SubmitResponse
        if attachments.isEmpty {
            response = try await network.requestDecoded(
                endpoint: endpoint,
                body: request,
                responseType: SubmitResponse.self
            )
        } else {
            // Multipart: the JSON payload rides in a `data` field, each file as
            // `attachments_n` (matching the web client's submit request).
            let encoder = JSONEncoder()
            let json = try encoder.encode(request)
            let dataField = MultipartTextField(name: "data", value: String(decoding: json, as: UTF8.self))
            let files = attachments.enumerated().map { index, attachment in
                MultipartFile(
                    field: "attachments_\(index)",
                    filename: attachment.filename,
                    mimeType: attachment.mimeType,
                    data: attachment.data
                )
            }
            response = try await network.requestMultipartDecoded(
                endpoint: endpoint,
                textFields: [dataField],
                files: files,
                responseType: SubmitResponse.self
            )
        }

        guard let dto = response.data else { throw NetworkError.noData }
        return CashReceipt(dto: dto)
    }

    // MARK: - Pickers

    /// Envelope for `/accounts`: `{ data: { accounts, total }, message }`.
    private nonisolated struct AccountsResponse: Codable, Sendable {
        let data: Payload?
        nonisolated struct Payload: Codable, Sendable {
            let accounts: [AccountDTO]?
        }
    }

    func fetchCashAccounts() async throws -> [AccountDTO] {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.accounts,
            method: .get,
            // `include_balance=true` makes the endpoint return each account's
            // `balance`, surfaced as the trailing value in the cash-account picker.
            parameters: [
                "is_header": "false",
                "is_active": "true",
                "include_balance": "true",
                "limit": "200"
            ]
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: AccountsResponse.self
        )
        return (response.data?.accounts ?? []).filter { $0.isCashBank }
    }

    /// FX response from `api.frankfurter.dev/v1/latest?base=…&symbols=IDR`.
    private nonisolated struct FrankfurterResponse: Decodable, Sendable {
        let rates: [String: Double]?
    }

    func fetchExchangeRate(base: String) async throws -> Double {
        guard base.uppercased() != "IDR",
              let url = URL(string: "https://api.frankfurter.dev/v1/latest?base=\(base)&symbols=IDR")
        else { return 1 }
        let (data, _) = try await URLSession.shared.data(from: url)
        let decoded = try JSONDecoder().decode(FrankfurterResponse.self, from: data)
        guard let rate = decoded.rates?["IDR"], rate > 0 else { throw NetworkError.noData }
        return rate.rounded()
    }

    func fetchBranches() async throws -> [BranchDTO] {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.baseURL,
            path: AppURLConstants.Core.branches,
            method: .get,
            parameters: ["page": "1", "limit": "100", "is_active": "true"]
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: PaginatedResponse<BranchDTO>.self
        )
        return response.data ?? []
    }

    // MARK: - Detail / approval / delete / update

    func fetchDetail(id: String) async throws -> CashTransactionDetailDTO {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.cashTransaction(id),
            method: .get
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: CashTransactionDetailResponse.self
        )
        guard let dto = response.data else { throw NetworkError.noData }
        return dto
    }

    @discardableResult
    func approve(id: String, comment: String) async throws -> CashTransactionDetailDTO {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.cashTransactionApprove(id),
            method: .post
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: ApproveRequest(comment: comment),
            responseType: CashTransactionDetailResponse.self
        )
        guard let dto = response.data else { throw NetworkError.noData }
        return dto
    }

    @discardableResult
    func reject(id: String, reason: String) async throws -> CashTransactionDetailDTO {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.cashTransactionReject(id),
            method: .post
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: RejectRequest(reason: reason),
            responseType: CashTransactionDetailResponse.self
        )
        guard let dto = response.data else { throw NetworkError.noData }
        return dto
    }

    func delete(id: String) async throws {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.cashTransaction(id),
            method: .delete
        )
        // Response is `{ data: null, message }`; SubmitResponse tolerates null data.
        _ = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: SubmitResponse.self
        )
    }

    @discardableResult
    func update(id: String, request: CashTransactionRequest) async throws -> CashTransactionDetailDTO {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.cashTransaction(id),
            method: .put
        )
        // PUT returns the full detail (same shape as the `{id}` GET), whose
        // `lines` carry server ids — needed to attach files post-update.
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: request,
            responseType: CashTransactionDetailResponse.self
        )
        guard let dto = response.data else { throw NetworkError.noData }
        return dto
    }

    /// Envelope for the line-attachment upload: `{ data: CashAttachmentDTO, message }`.
    private nonisolated struct AttachmentResponse: Codable, Sendable {
        let data: CashAttachmentDTO?
        let message: String?
    }

    @discardableResult
    func uploadLineAttachment(
        transactionId: String,
        lineId: String,
        attachment: CashAttachment
    ) async throws -> CashLineAttachment {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.cashTransactionLineAttachments(transactionId, lineId),
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
                "reff_type": "finance.cash_transactions",
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
