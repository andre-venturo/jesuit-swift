//
//  AccountModels.swift
//  Jesuit
//
//  Models for the Master Akun (chart of accounts) management slice.
//  Contract verified against the web app's captured `/accounts` traffic:
//  `{ data: { accounts: [...], total }, message }` — each account carries
//  account_type (asset/liability/equity/revenue/expense) + *_label strings,
//  account_sub_type (+label), normal_balance, hierarchy (parent_id/level/
//  is_header) and, with include_balance=true, total_debit/total_credit/balance.
//  Deliberately separate from `AccountDTO` (CashReceiptModels) — that leaner
//  DTO feeds every account picker and must stay untouched.
//

import Foundation

// MARK: - Account type

/// Chart-of-accounts type. Raw values are the server vocabulary ("asset" and
/// "revenue" verified in captures); labels match the web app's Indonesian UI
/// (Harta / Pendapatan verified). Unknown raw values decode to `nil` and
/// bucket as "Lainnya", displaying the server's `account_type_label`.
enum AccountType: String, CaseIterable, Identifiable, Sendable {
    case asset, liability, equity, revenue, expense

    var id: String { rawValue }

    var label: String {
        switch self {
        case .asset: "Harta"
        case .liability: "Kewajiban"
        case .equity: "Modal"
        case .revenue: "Pendapatan"
        case .expense: "Beban"
        }
    }
}

// MARK: - DTO

nonisolated struct ChartAccountDTO: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let code: String?
    /// Raw server value — mapped to `AccountType?` at the entity layer so an
    /// unknown type never fails decoding.
    let accountType: String?
    let accountTypeLabel: String?
    let accountSubType: String?
    let accountSubTypeLabel: String?
    let currencyCode: String?
    let normalBalance: String?
    let isActive: Bool?
    let isHeader: Bool?
    let parentId: String?
    let description: String?
    let balance: Double?
    let totalDebit: Double?
    let totalCredit: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, code, description, balance
        case accountType = "account_type"
        case accountTypeLabel = "account_type_label"
        case accountSubType = "account_sub_type"
        case accountSubTypeLabel = "account_sub_type_label"
        case currencyCode = "currency_code"
        case normalBalance = "normal_balance"
        case isActive = "is_active"
        case isHeader = "is_header"
        case parentId = "parent_id"
        case totalDebit = "total_debit"
        case totalCredit = "total_credit"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = (try? c.decode(String.self, forKey: .name)) ?? ""
        code = try? c.decode(String.self, forKey: .code)
        accountType = try? c.decode(String.self, forKey: .accountType)
        accountTypeLabel = try? c.decode(String.self, forKey: .accountTypeLabel)
        accountSubType = try? c.decode(String.self, forKey: .accountSubType)
        accountSubTypeLabel = try? c.decode(String.self, forKey: .accountSubTypeLabel)
        currencyCode = try? c.decode(String.self, forKey: .currencyCode)
        normalBalance = try? c.decode(String.self, forKey: .normalBalance)
        isActive = try? c.decode(Bool.self, forKey: .isActive)
        isHeader = try? c.decode(Bool.self, forKey: .isHeader)
        parentId = try? c.decode(String.self, forKey: .parentId)
        description = try? c.decode(String.self, forKey: .description)
        balance = Self.flexibleDouble(c, .balance)
        totalDebit = Self.flexibleDouble(c, .totalDebit)
        totalCredit = Self.flexibleDouble(c, .totalCredit)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(code, forKey: .code)
        try c.encodeIfPresent(accountType, forKey: .accountType)
        try c.encodeIfPresent(accountSubType, forKey: .accountSubType)
        try c.encodeIfPresent(currencyCode, forKey: .currencyCode)
        try c.encodeIfPresent(normalBalance, forKey: .normalBalance)
        try c.encodeIfPresent(isActive, forKey: .isActive)
        try c.encodeIfPresent(isHeader, forKey: .isHeader)
        try c.encodeIfPresent(parentId, forKey: .parentId)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(balance, forKey: .balance)
    }

    /// Accepts a number encoded as a JSON number or a numeric string.
    private static func flexibleDouble(
        _ container: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
    ) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) { return value }
        if let str = try? container.decode(String.self, forKey: key) { return Double(str) }
        return nil
    }
}

/// Envelope for `GET /accounts`: `{ data: { accounts, total }, message }` —
/// same shape CashReceiptRepository decodes for the pickers. No pagination.
nonisolated struct ChartAccountsResponse: Codable, Sendable {
    let data: Payload?
    let message: String?

    nonisolated struct Payload: Codable, Sendable {
        let accounts: [ChartAccountDTO]?
        let total: Int?
    }
}

// MARK: - Entity

struct ChartAccount: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let code: String?
    /// Mapped type, nil when the server sent an unknown/missing value.
    let type: AccountType?
    /// The server's raw type string, preserved for round-tripping on edit.
    let typeRaw: String?
    /// Display label for the type: our Indonesian label for known types, the
    /// server's `account_type_label` for unknown ones.
    let typeLabel: String
    let subType: String?
    /// Server display label for the sub-type (e.g. "Cash & Bank").
    let subTypeLabel: String?
    let currencyCode: String?
    /// "debit" / "credit".
    let normalBalance: String?
    let isActive: Bool
    let isHeader: Bool
    let parentId: String?
    let description: String?
    let balance: Double?
    let totalDebit: Double?
    let totalCredit: Double?

    init(dto: ChartAccountDTO) {
        id = dto.id
        name = dto.name
        code = dto.code
        type = dto.accountType.flatMap(AccountType.init(rawValue:))
        typeRaw = dto.accountType
        typeLabel = type?.label ?? dto.accountTypeLabel ?? dto.accountType ?? "—"
        subType = dto.accountSubType
        subTypeLabel = dto.accountSubTypeLabel ?? dto.accountSubType
        currencyCode = dto.currencyCode
        normalBalance = dto.normalBalance
        isActive = dto.isActive ?? true
        isHeader = dto.isHeader ?? false
        parentId = dto.parentId
        description = dto.description
        balance = dto.balance
        totalDebit = dto.totalDebit
        totalCredit = dto.totalCredit
    }
}

// MARK: - Save request / response

/// Body for `POST /accounts` and `PUT /accounts/{id}`. Keys mirror the read
/// payload's verified snake_case names; isolated here for one-line renames.
nonisolated struct SaveAccountRequest: Codable, Sendable {
    let name: String
    let accountType: String
    let code: String?
    let accountSubType: String?
    let currencyCode: String?
    let description: String?
    let parentId: String?
    let isActive: Bool

    enum CodingKeys: String, CodingKey {
        case name, code, description
        case accountType = "account_type"
        case accountSubType = "account_sub_type"
        case currencyCode = "currency_code"
        case parentId = "parent_id"
        case isActive = "is_active"
    }
}

/// Envelope for write responses. Writes may return the account either bare or
/// nested (`{ data: { account: {...} } }`) — both tolerated; `data` optional so
/// a `{ data: null }` DELETE response decodes fine.
nonisolated struct SaveAccountResponse: Codable, Sendable {
    let data: DataValue?
    let message: String?

    nonisolated enum DataValue: Codable, Sendable {
        case account(ChartAccountDTO)
        case nested(ChartAccountDTO)

        var dto: ChartAccountDTO {
            switch self {
            case .account(let dto), .nested(let dto): dto
            }
        }

        nonisolated private struct Nested: Codable, Sendable { let account: ChartAccountDTO? }

        init(from decoder: Decoder) throws {
            if let bare = try? ChartAccountDTO(from: decoder), !bare.id.isEmpty {
                self = .account(bare)
                return
            }
            let nested = try Nested(from: decoder)
            guard let dto = nested.account else {
                throw DecodingError.dataCorrupted(.init(
                    codingPath: decoder.codingPath,
                    debugDescription: "Neither a bare account nor { account: ... }"
                ))
            }
            self = .nested(dto)
        }

        func encode(to encoder: Encoder) throws {
            try dto.encode(to: encoder)
        }
    }
}
