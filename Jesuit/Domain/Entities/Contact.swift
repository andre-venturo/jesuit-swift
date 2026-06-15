//
//  Contact.swift
//  Jesuit
//
//  Customer / vendor contact entity.
//

import Foundation

struct Contact: Identifiable, Sendable {
    enum Kind: String, Sendable {
        case customer = "Customer"
        case vendor = "Vendor"
    }

    let id: String
    let name: String
    let company: String
    let kind: Kind
    let balance: Double

    // Editable fields carried from the list DTO, for the edit form.
    let categoryId: String?
    let email: String?
    let phone: String?
    let address: String?
    let picName: String?
    let picPosition: String?
    let isActive: Bool

    init(
        id: String = UUID().uuidString,
        name: String,
        company: String,
        kind: Kind,
        balance: Double,
        categoryId: String? = nil,
        email: String? = nil,
        phone: String? = nil,
        address: String? = nil,
        picName: String? = nil,
        picPosition: String? = nil,
        isActive: Bool = true
    ) {
        self.id = id
        self.name = name
        self.company = company
        self.kind = kind
        self.balance = balance
        self.categoryId = categoryId
        self.email = email
        self.phone = phone
        self.address = address
        self.picName = picName
        self.picPosition = picPosition
        self.isActive = isActive
    }

    /// Outstanding amount the contact owes (positive balance).
    var receivables: Double { max(balance, 0) }

    /// Credit the contact holds (negative balance, shown as a positive figure).
    var credits: Double { max(-balance, 0) }

    /// Initials for the avatar, e.g. "Dr. Ilham H" → "IH".
    var initials: String {
        let words = name.split(separator: " ").filter { !$0.hasSuffix(".") }
        let picked = (words.isEmpty ? name.split(separator: " ") : words)
        return picked.prefix(2).compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

extension Contact {
    /// Maps a finance `ContactDTO` to the UI entity. Category code `VND`
    /// (or a payable category) marks a vendor; everything else is a customer.
    init(dto: ContactDTO) {
        let code = dto.categoryCode?.uppercased()
        let categoryName = dto.categoryName?.lowercased()
        let isVendor = code == "VND" || categoryName == "vendor"

        self.init(
            id: dto.id,
            name: dto.name,
            company: dto.companyName ?? dto.email ?? "",
            kind: isVendor ? .vendor : .customer,
            balance: dto.balance ?? 0,
            categoryId: dto.categoryId,
            email: dto.email,
            phone: dto.phone,
            address: dto.address,
            picName: dto.picName,
            picPosition: dto.picPosition,
            isActive: dto.isActive ?? true
        )
    }
}
