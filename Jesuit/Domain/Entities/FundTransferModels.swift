//
//  FundTransferModels.swift
//  Jesuit
//
//  Domain entities + DTOs for "Transfer Dana" (fund transfers) — moving money
//  between two cash/bank accounts. Backed by /finance/v1/fund-transfers. Unlike
//  cash transactions, a transfer has no journal lines: it's a single header
//  (from account/branch → to account/branch + amount, with an optional FX leg).
//
//  Reuses the cash-transaction primitives where they fit: `ReceiptStatus` (same
//  draft/waiting/posted/rejected workflow), `AccountDTO`/`BranchDTO` pickers,
//  `CashAttachment`/`CashLineAttachment`/`CashAttachmentDTO`, `CashTransactionCounts`
//  and the `ApproveRequest`/`RejectRequest` bodies.
//

import Foundation

// MARK: - List row

/// A single fund-transfer row for the Transfer Dana list.
struct FundTransfer: Identifiable, Sendable {
    let id: String
    let number: String          // No. Transfer (transfer_no)
    let date: Date              // Tanggal
    let description: String
    let amount: Double          // IDR
    let currencyCode: String    // header IDR
    let status: ReceiptStatus
    let createdAt: Date
    let updatedAt: Date
    let fromAccountId: String?
    let toAccountId: String?

    /// Amount formatted in the transfer's (IDR) currency.
    var amountText: String { amount.asCurrency(currencyCode) }

    init(dto: FundTransferDTO) {
        id = dto.id
        number = dto.transferNo ?? "-"
        date = dto.transferDate ?? dto.createdAt ?? .now
        description = dto.description ?? ""
        amount = dto.amount ?? 0
        currencyCode = "IDR"
        status = ReceiptStatus(apiStatus: dto.status)
        createdAt = dto.createdAt ?? dto.transferDate ?? .now
        updatedAt = dto.updatedAt ?? dto.createdAt ?? dto.transferDate ?? .now
        fromAccountId = dto.fromAccountId
        toAccountId = dto.toAccountId
    }
}

// MARK: - Detail

/// Full fund-transfer detail for the detail sheet (names resolved client-side
/// from the accounts/branches lists; the payload carries only ids).
struct FundTransferDetail: Sendable {
    let id: String
    let number: String
    let date: Date
    let description: String
    let fromAccountId: String?
    let fromAccountName: String
    let fromBranchName: String
    let toAccountId: String?
    let toAccountName: String
    let toBranchName: String
    let amount: Double           // IDR
    let currencyCode: String     // "IDR"
    // FX leg (when from/to currencies differ).
    let fromCurrencyCode: String
    let toCurrencyCode: String
    let exchangeRate: Double
    let originalAmount: Double
    let status: ReceiptStatus
    /// Raw API status ("draft"/"waiting"/"posted"/"rejected") for action gating.
    let rawStatus: String
    let approvalLevel: Int?
    let totalApprovalLevels: Int?
    let hasJournal: Bool
    let createdAt: Date
    let createdById: String?
    let updatedAt: Date
    let attachments: [CashLineAttachment]

    /// True when the two legs are in different currencies (FX transfer).
    var isForeign: Bool { fromCurrencyCode.uppercased() != toCurrencyCode.uppercased() }

    /// The non-IDR currency code, for the FX summary row ("" when both IDR).
    var foreignCurrency: String {
        if fromCurrencyCode.uppercased() != "IDR" { return fromCurrencyCode }
        if toCurrencyCode.uppercased() != "IDR" { return toCurrencyCode }
        return ""
    }
}

// MARK: - Create request (POST /finance/v1/fund-transfers[/submit])

/// Body for creating / updating a fund transfer. Mirrors the web client's
/// `CreateFundTransferPayload`. FX fields default to IDR/IDR/1/0 (the BE default
/// for a same-currency transfer), so they're always sent rather than omitted.
nonisolated struct CreateFundTransferRequest: Codable, Sendable {
    let transferDate: String     // "yyyy-MM-dd"
    let description: String
    let fromAccountId: String
    let fromBranchId: String
    let toAccountId: String
    let toBranchId: String
    let amount: Double           // IDR
    let fromCurrencyCode: String
    let toCurrencyCode: String
    let exchangeRate: Double
    let originalAmount: Double

    enum CodingKeys: String, CodingKey {
        case description, amount
        case transferDate = "transfer_date"
        case fromAccountId = "from_account_id"
        case fromBranchId = "from_branch_id"
        case toAccountId = "to_account_id"
        case toBranchId = "to_branch_id"
        case fromCurrencyCode = "from_currency_code"
        case toCurrencyCode = "to_currency_code"
        case exchangeRate = "exchange_rate"
        case originalAmount = "original_amount"
    }

    init(
        date: Date,
        description: String,
        fromAccountId: String,
        fromBranchId: String,
        toAccountId: String,
        toBranchId: String,
        amount: Double,
        fromCurrencyCode: String = "IDR",
        toCurrencyCode: String = "IDR",
        exchangeRate: Double = 1,
        originalAmount: Double = 0
    ) {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        transferDate = df.string(from: date)
        self.description = description
        self.fromAccountId = fromAccountId
        self.fromBranchId = fromBranchId
        self.toAccountId = toAccountId
        self.toBranchId = toBranchId
        self.amount = amount
        // A same-currency transfer always rides as IDR/IDR/1/0; an FX leg carries
        // the foreign currency on whichever account isn't IDR.
        let isForeign = fromCurrencyCode.uppercased() != toCurrencyCode.uppercased()
        self.fromCurrencyCode = isForeign ? fromCurrencyCode : "IDR"
        self.toCurrencyCode = isForeign ? toCurrencyCode : "IDR"
        self.exchangeRate = isForeign ? (exchangeRate > 0 ? exchangeRate : 1) : 1
        self.originalAmount = isForeign ? originalAmount : 0
    }
}

// MARK: - DTOs

/// Pagination + per-status counts envelope for the fund-transfers list.
nonisolated struct FundTransferListResponse: Codable, Sendable {
    let data: [FundTransferDTO]?
    let message: String?
    let meta: Meta?

    nonisolated struct Meta: Codable, Sendable {
        let pagination: PaginatedResponse<FundTransferDTO>.Pagination?
        let counts: CashTransactionCounts?
    }
}

nonisolated struct FundTransferDetailResponse: Codable, Sendable {
    let data: FundTransferDTO?
    let message: String?
}

/// One fund-transfer item. The list and detail endpoints return the same shape
/// (per the web `FundTransfer` type). Every field beyond `id` is decoded
/// leniently and tolerant of number-or-string amounts and ISO/`yyyy-MM-dd` dates.
nonisolated struct FundTransferDTO: Codable, Sendable, Identifiable {
    let id: String
    let transferNo: String?
    let transferDate: Date?
    let description: String?
    let fromAccountId: String?
    let fromBranchId: String?
    let toAccountId: String?
    let toBranchId: String?
    let amount: Double?
    let fromCurrencyCode: String?
    let toCurrencyCode: String?
    let exchangeRate: Double?
    let originalAmount: Double?
    let status: String?
    let currentApprovalLevel: Int?
    let totalApprovalLevels: Int?
    let journalEntryId: String?
    let attachments: [CashAttachmentDTO]?
    let createdAt: Date?
    let createdBy: String?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, description, amount, status, attachments
        case transferNo = "transfer_no"
        case transferDate = "transfer_date"
        case fromAccountId = "from_account_id"
        case fromBranchId = "from_branch_id"
        case toAccountId = "to_account_id"
        case toBranchId = "to_branch_id"
        case fromCurrencyCode = "from_currency_code"
        case toCurrencyCode = "to_currency_code"
        case exchangeRate = "exchange_rate"
        case originalAmount = "original_amount"
        case currentApprovalLevel = "current_approval_level"
        case totalApprovalLevels = "total_approval_levels"
        case journalEntryId = "journal_entry_id"
        case createdAt = "created_at"
        case createdBy = "created_by"
        case updatedAt = "updated_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        transferNo = try? c.decode(String.self, forKey: .transferNo)
        description = try? c.decode(String.self, forKey: .description)
        status = try? c.decode(String.self, forKey: .status)
        fromAccountId = try? c.decode(String.self, forKey: .fromAccountId)
        fromBranchId = try? c.decode(String.self, forKey: .fromBranchId)
        toAccountId = try? c.decode(String.self, forKey: .toAccountId)
        toBranchId = try? c.decode(String.self, forKey: .toBranchId)
        fromCurrencyCode = try? c.decode(String.self, forKey: .fromCurrencyCode)
        toCurrencyCode = try? c.decode(String.self, forKey: .toCurrencyCode)
        journalEntryId = try? c.decode(String.self, forKey: .journalEntryId)
        createdBy = try? c.decode(String.self, forKey: .createdBy)
        currentApprovalLevel = try? c.decode(Int.self, forKey: .currentApprovalLevel)
        totalApprovalLevels = try? c.decode(Int.self, forKey: .totalApprovalLevels)
        attachments = try? c.decode([CashAttachmentDTO].self, forKey: .attachments)
        amount = Self.flexibleDouble(c, .amount)
        exchangeRate = Self.flexibleDouble(c, .exchangeRate)
        originalAmount = Self.flexibleDouble(c, .originalAmount)
        transferDate = Self.flexibleDate(c, .transferDate)
        createdAt = Self.flexibleDate(c, .createdAt)
        updatedAt = Self.flexibleDate(c, .updatedAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(transferNo, forKey: .transferNo)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(amount, forKey: .amount)
    }

    private static func flexibleDouble(
        _ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
    ) -> Double? {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key) { return Double(s) }
        return nil
    }

    private static func flexibleDate(
        _ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
    ) -> Date? {
        guard let str = try? c.decode(String.self, forKey: key), !str.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: str) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: str) { return d }
        let ymd = DateFormatter()
        ymd.locale = Locale(identifier: "en_US_POSIX")
        ymd.dateFormat = "yyyy-MM-dd"
        return ymd.date(from: str)
    }
}
