//
//  CashReceiptRepositoryProtocol.swift
//  Jesuit
//
//  Abstraction over the wizhub finance cash-transactions endpoint, scoped to
//  receipts (Penerimaan Kas).
//

import Foundation

struct CashReceiptPage: Sendable {
    let receipts: [CashReceipt]
    let counts: CashTransactionCounts?
    let page: Int
    let totalPages: Int
    let total: Int
}

protocol CashReceiptRepositoryProtocol: Sendable {
    /// Fetches a page of cash receipts (`transaction_type=receipt`), mapped to
    /// the UI `CashReceipt` entity, along with the per-status counts used by the
    /// filter tabs.
    func fetchReceipts(page: Int, limit: Int) async throws -> CashReceiptPage

    /// Fetches a page of cash disbursements (`transaction_type=disbursement`),
    /// the Pengeluaran (expenses) side of the same endpoint. Same shape and
    /// per-status counts as `fetchReceipts`.
    func fetchDisbursements(page: Int, limit: Int) async throws -> CashReceiptPage

    /// Creates and submits a cash transaction (POST `/cash-transactions/submit`),
    /// returning the created row. When `attachments` is non-empty the payload is
    /// sent as `multipart/form-data` (`data` JSON field + `attachments_n` files).
    @discardableResult
    func submit(_ request: CashTransactionRequest, attachments: [CashAttachment]) async throws -> CashReceipt

    /// Creates a cash transaction as a draft (POST `/cash-transactions`),
    /// returning the created row. Same multipart behaviour as `submit`.
    @discardableResult
    func saveDraft(_ request: CashTransactionRequest, attachments: [CashAttachment]) async throws -> CashReceipt

    /// Active cash/bank accounts, for the create-transaction cash-account picker.
    func fetchCashAccounts() async throws -> [AccountDTO]

    /// Active, non-header **asset** accounts (with balance) — the set offered as
    /// fund-transfer legs (which include cash/bank *and* other asset accounts such
    /// as receivables, unlike the cash/bank-only `fetchCashAccounts`). Also used to
    /// resolve transfer-leg account names.
    func fetchAssetAccounts() async throws -> [AccountDTO]

    /// Active company branches, for the create-transaction branch picker.
    func fetchBranches() async throws -> [BranchDTO]

    /// Current `base`→IDR exchange rate (rounded to a whole rupiah), used to
    /// prefill the Kurs field when a foreign-currency cash account is selected.
    /// Hits an external FX host directly (no auth).
    func fetchExchangeRate(base: String) async throws -> Double

    /// Loads one transaction's full detail (`GET /cash-transactions/{id}`).
    func fetchDetail(id: String) async throws -> CashTransactionDetailDTO

    /// Approves the transaction (`POST .../{id}/approve`). `comment` may be empty.
    @discardableResult
    func approve(id: String, comment: String) async throws -> CashTransactionDetailDTO

    /// Rejects the transaction (`POST .../{id}/reject`) with a required reason.
    @discardableResult
    func reject(id: String, reason: String) async throws -> CashTransactionDetailDTO

    /// Deletes the transaction (`DELETE /cash-transactions/{id}`).
    func delete(id: String) async throws

    /// Updates a transaction (`PUT /cash-transactions/{id}`) — same body as
    /// create minus `transaction_type`. Returns the full detail (whose `lines`
    /// carry server ids) so callers can upload edit-time attachments to the
    /// right line, including lines added during the edit.
    @discardableResult
    func update(id: String, request: CashTransactionRequest) async throws -> CashTransactionDetailDTO

    /// Uploads a file to an existing transaction line
    /// (`POST /cash-transactions/{id}/lines/{lineId}/attachments`), returning the
    /// stored attachment.
    @discardableResult
    func uploadLineAttachment(
        transactionId: String,
        lineId: String,
        attachment: CashAttachment
    ) async throws -> CashLineAttachment

    /// Loads a transaction's activity log for the detail "Riwayat" tab
    /// (`GET /core/v1/audit-logs?reff_type=finance.cash_transactions&reff_id={id}`),
    /// newest first.
    func fetchActivity(reffId: String) async throws -> [AuditLogDTO]
}
