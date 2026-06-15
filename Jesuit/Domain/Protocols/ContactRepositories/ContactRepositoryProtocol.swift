//
//  ContactRepositoryProtocol.swift
//  Jesuit
//
//  Abstraction over the wizhub finance contact endpoints.
//

import Foundation

struct ContactPage: Sendable {
    let contacts: [Contact]
    let page: Int
    let totalPages: Int
    let total: Int
}

protocol ContactRepositoryProtocol: Sendable {
    /// Fetches a page of contacts, mapped to the UI `Contact` entity.
    func fetchContacts(page: Int, limit: Int) async throws -> ContactPage

    /// Fetches the configured contact categories (e.g. Customer, Vendor).
    func fetchCategories() async throws -> [ContactCategoryDTO]

    /// Creates a contact (`POST /finance/v1/contacts`) and returns it mapped to
    /// the UI entity.
    @discardableResult
    func createContact(_ request: CreateContactRequest) async throws -> Contact
}
