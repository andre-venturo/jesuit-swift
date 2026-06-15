//
//  ContactRepository.swift
//  Jesuit
//
//  Concrete implementation of the finance contact endpoints.
//

import Foundation

struct ContactRepository: ContactRepositoryProtocol {
    private let network: NetworkServiceProtocol

    init(network: NetworkServiceProtocol) {
        self.network = network
    }

    func fetchContacts(page: Int, limit: Int) async throws -> ContactPage {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.contacts,
            method: .get,
            parameters: ["page": String(page), "limit": String(limit)]
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: PaginatedResponse<ContactDTO>.self
        )

        let contacts = (response.data ?? []).map(Contact.init(dto:))
        let pagination = response.meta?.pagination
        return ContactPage(
            contacts: contacts,
            page: pagination?.page ?? page,
            totalPages: pagination?.totalPages ?? 0,
            total: pagination?.total ?? contacts.count
        )
    }

    func fetchCategories() async throws -> [ContactCategoryDTO] {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.contactCategories,
            method: .get
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: PaginatedResponse<ContactCategoryDTO>.self
        )
        return response.data ?? []
    }

    @discardableResult
    func createContact(_ request: CreateContactRequest) async throws -> Contact {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.contacts,
            method: .post
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: request,
            responseType: CreateContactResponse.self
        )
        guard let dto = response.data else { throw NetworkError.noData }
        return Contact(dto: dto)
    }
}
