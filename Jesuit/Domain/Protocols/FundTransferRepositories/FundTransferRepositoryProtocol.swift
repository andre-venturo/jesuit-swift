//
//  FundTransferRepositoryProtocol.swift
//  Jesuit
//
//  Abstraction over the wizhub finance fund-transfers endpoint (Transfer Dana).
//  Scoped to the transfer's own CRUD/lifecycle; account/branch/FX lookups are
//  reused from `CashReceiptRepositoryProtocol` rather than duplicated here.
//

import Foundation

struct FundTransferPage: Sendable {
    let transfers: [FundTransfer]
    let counts: CashTransactionCounts?
    let page: Int
    let totalPages: Int
    let total: Int
}

protocol FundTransferRepositoryProtocol: Sendable {
    /// Fetches a page of fund transfers, mapped to the UI `FundTransfer` entity,
    /// with the per-status counts used by the filter tabs.
    func fetchTransfers(page: Int, limit: Int) async throws -> FundTransferPage

    /// Creates a transfer as a draft (POST `/fund-transfers`).
    @discardableResult
    func saveDraft(_ request: CreateFundTransferRequest) async throws -> FundTransfer

    /// Creates and submits a transfer (POST `/fund-transfers/submit`).
    @discardableResult
    func submit(_ request: CreateFundTransferRequest) async throws -> FundTransfer

    /// Loads one transfer's full detail (`GET /fund-transfers/{id}`).
    func fetchDetail(id: String) async throws -> FundTransferDTO

    /// Updates a transfer as a draft (`PUT /fund-transfers/{id}`).
    @discardableResult
    func update(id: String, request: CreateFundTransferRequest) async throws -> FundTransferDTO

    /// Updates and submits a transfer (`POST /fund-transfers/{id}/submit`).
    @discardableResult
    func updateAndSubmit(id: String, request: CreateFundTransferRequest) async throws -> FundTransferDTO

    /// Approves the transfer (`POST .../{id}/approve`). `comment` may be empty.
    @discardableResult
    func approve(id: String, comment: String) async throws -> FundTransferDTO

    /// Rejects the transfer (`POST .../{id}/reject`) with a required reason.
    @discardableResult
    func reject(id: String, reason: String) async throws -> FundTransferDTO

    /// Deletes the transfer (`DELETE /fund-transfers/{id}`).
    func delete(id: String) async throws

    /// Uploads a file to a transfer (`POST /fund-transfers/{id}/attachments`).
    @discardableResult
    func uploadAttachment(id: String, attachment: CashAttachment) async throws -> CashLineAttachment

    /// Loads a transfer's activity log for the detail "Riwayat" tab.
    func fetchActivity(reffId: String) async throws -> [AuditLogDTO]
}
