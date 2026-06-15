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
    /// returning the created row.
    @discardableResult
    func submit(_ request: CashTransactionRequest) async throws -> CashReceipt

    /// Creates a cash transaction as a draft (POST `/cash-transactions`),
    /// returning the created row.
    @discardableResult
    func saveDraft(_ request: CashTransactionRequest) async throws -> CashReceipt

    /// Active cash/bank accounts, for the create-transaction cash-account picker.
    func fetchCashAccounts() async throws -> [AccountDTO]

    /// Active company branches, for the create-transaction branch picker.
    func fetchBranches() async throws -> [BranchDTO]
}
