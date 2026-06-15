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
    func submit(_ request: CashTransactionRequest) async throws -> CashReceipt {
        try await post(path: AppURLConstants.Finance.cashTransactionsSubmit, request: request)
    }

    @discardableResult
    func saveDraft(_ request: CashTransactionRequest) async throws -> CashReceipt {
        // Same payload as submit, un-suffixed collection path (the web client's
        // "Simpan Draft" posts to /cash-transactions).
        try await post(path: AppURLConstants.Finance.cashTransactions, request: request)
    }

    private func post(path: String, request: CashTransactionRequest) async throws -> CashReceipt {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: path,
            method: .post
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: request,
            responseType: SubmitResponse.self
        )
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
            parameters: ["is_header": "false", "is_active": "true", "limit": "200"]
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: AccountsResponse.self
        )
        return (response.data?.accounts ?? []).filter { $0.isCashBank }
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
}
