//
//  AccountRepositoryProtocol.swift
//  Jesuit
//
//  Chart-of-accounts (Master Akun) management. Read side of the same
//  `/accounts` endpoint the pickers use, plus the write endpoints.
//

import Foundation

protocol AccountRepositoryProtocol: Sendable {
    /// The full chart in one call — all types, headers INCLUDED, active +
    /// inactive (no `is_header`/`is_active` params: the management list must
    /// show everything, unlike the pickers), with balances. The endpoint is
    /// not paginated; it returns `{ data: { accounts, total } }`.
    func fetchAccounts() async throws -> [ChartAccount]

    /// `POST /accounts`.
    @discardableResult
    func create(_ request: SaveAccountRequest) async throws -> ChartAccount

    /// `PUT /accounts/{id}`.
    @discardableResult
    func update(id: String, request: SaveAccountRequest) async throws -> ChartAccount

    /// `DELETE /accounts/{id}`.
    func delete(id: String) async throws
}
