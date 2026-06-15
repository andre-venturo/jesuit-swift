//
//  ContactModels.swift
//  Jesuit
//
//  DTOs for the wizhub finance contact endpoints
//  (GET /finance/v1/contacts and /finance/v1/contact-categories).
//
//  Note: the captured HAR returned an empty contacts list, so the contact
//  item fields below are decoded leniently (all optional beyond id/name) to
//  tolerate whatever the live API emits.
//

import Foundation

// MARK: - Paginated envelope

/// Matches the finance API shape `{ data, message, meta: { pagination, counts } }`,
/// which differs from the core `APIResponse` (status/code/data).
nonisolated struct PaginatedResponse<T: Codable & Sendable>: Codable, Sendable {
    let data: [T]?
    let message: String?
    let meta: Meta?

    nonisolated struct Meta: Codable, Sendable {
        let pagination: Pagination?
        let counts: Counts?
    }

    nonisolated struct Pagination: Codable, Sendable {
        let page: Int?
        let limit: Int?
        let total: Int?
        let totalPages: Int?

        enum CodingKeys: String, CodingKey {
            case page, limit, total
            case totalPages = "total_pages"
        }
    }

    nonisolated struct Counts: Codable, Sendable {
        let all: Int?
    }
}

// MARK: - Contact category

nonisolated struct ContactCategoryDTO: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let code: String?
    let isPayable: Bool?
    let isReceivable: Bool?
    let isDefault: Bool?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, code
        case isPayable = "is_payable"
        case isReceivable = "is_receivable"
        case isDefault = "is_default"
        case isActive = "is_active"
    }
}

// MARK: - Create contact

/// Body for `POST /finance/v1/contacts`.
nonisolated struct CreateContactRequest: Codable, Sendable {
    let name: String
    let categoryId: String
    let email: String?
    let phone: String?
    let address: String?
    let picName: String?
    let picPosition: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case name, email, phone, address
        case categoryId = "category_id"
        case picName = "pic_name"
        case picPosition = "pic_position"
        case isActive = "is_active"
    }
}

/// Envelope for the create response: `{ data: ContactDTO, message }`.
nonisolated struct CreateContactResponse: Codable, Sendable {
    let data: ContactDTO?
    let message: String?
}

// MARK: - Contact

nonisolated struct ContactDTO: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let companyName: String?
    let email: String?
    let phone: String?
    let address: String?
    let picName: String?
    let picPosition: String?
    let isActive: Bool?
    let categoryId: String?
    let categoryName: String?
    let categoryCode: String?
    let balance: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, email, phone, balance, category, address
        case companyName = "company_name"
        case categoryId = "category_id"
        case categoryIdAlt = "contact_category_id"
        case categoryNameSnake = "category_name"
        case categoryCodeSnake = "category_code"
        case picName = "pic_name"
        case picPosition = "pic_position"
        case isActive = "is_active"
    }

    /// Nested `{ category: { id, name, code } }` object, when present.
    private enum CategoryKeys: String, CodingKey {
        case id, name, code
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        companyName = try? c.decode(String.self, forKey: .companyName)
        email = try? c.decode(String.self, forKey: .email)
        phone = try? c.decode(String.self, forKey: .phone)
        address = try? c.decode(String.self, forKey: .address)
        picName = try? c.decode(String.self, forKey: .picName)
        picPosition = try? c.decode(String.self, forKey: .picPosition)
        isActive = try? c.decode(Bool.self, forKey: .isActive)
        balance = ContactDTO.decodeFlexibleDouble(c, forKey: .balance)

        // Category may arrive flat (category_id/_name/_code) or nested under a
        // `category` object. Prefer the flat id, then the nested object's id.
        let flatId = (try? c.decode(String.self, forKey: .categoryId))
            ?? (try? c.decode(String.self, forKey: .categoryIdAlt))
        if let nested = try? c.nestedContainer(keyedBy: CategoryKeys.self, forKey: .category) {
            categoryId = flatId ?? (try? nested.decode(String.self, forKey: .id))
            categoryName = try? nested.decode(String.self, forKey: .name)
            categoryCode = try? nested.decode(String.self, forKey: .code)
        } else {
            categoryId = flatId
            categoryName = try? c.decode(String.self, forKey: .categoryNameSnake)
            categoryCode = try? c.decode(String.self, forKey: .categoryCodeSnake)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(companyName, forKey: .companyName)
        try c.encodeIfPresent(email, forKey: .email)
        try c.encodeIfPresent(phone, forKey: .phone)
        try c.encodeIfPresent(address, forKey: .address)
        try c.encodeIfPresent(picName, forKey: .picName)
        try c.encodeIfPresent(picPosition, forKey: .picPosition)
        try c.encodeIfPresent(isActive, forKey: .isActive)
        try c.encodeIfPresent(categoryId, forKey: .categoryId)
        try c.encodeIfPresent(balance, forKey: .balance)
    }

    /// Accepts a balance encoded as a JSON number or a numeric string.
    private static func decodeFlexibleDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) { return value }
        if let str = try? container.decode(String.self, forKey: key) { return Double(str) }
        return nil
    }
}
