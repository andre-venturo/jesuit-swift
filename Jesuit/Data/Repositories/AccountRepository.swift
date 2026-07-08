//
//  AccountRepository.swift
//  Jesuit
//
//  Concrete implementation of the chart-of-accounts management endpoints
//  (Master Akun). List envelope verified from the web app's captured traffic:
//  `{ data: { accounts, total }, message }` — not the paginated shape.
//

import Foundation

struct AccountRepository: AccountRepositoryProtocol {
    private let network: NetworkServiceProtocol

    init(network: NetworkServiceProtocol) {
        self.network = network
    }

    func fetchAccounts() async throws -> [ChartAccount] {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.accounts,
            method: .get,
            // No is_header/is_active filters — management shows everything.
            parameters: ["include_balance": "true"]
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: ChartAccountsResponse.self
        )
        return (response.data?.accounts ?? []).map(ChartAccount.init(dto:))
    }

    @discardableResult
    func create(_ request: SaveAccountRequest) async throws -> ChartAccount {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.accounts,
            method: .post
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: request,
            responseType: SaveAccountResponse.self
        )
        guard let dto = response.data?.dto else { throw NetworkError.noData }
        return ChartAccount(dto: dto)
    }

    @discardableResult
    func update(id: String, request: SaveAccountRequest) async throws -> ChartAccount {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.account(id),
            method: .put
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: request,
            responseType: SaveAccountResponse.self
        )
        guard let dto = response.data?.dto else { throw NetworkError.noData }
        return ChartAccount(dto: dto)
    }

    func delete(id: String) async throws {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.account(id),
            method: .delete
        )
        // Response is `{ data: null, message }`; SaveAccountResponse tolerates null data.
        _ = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: SaveAccountResponse.self
        )
    }
}
