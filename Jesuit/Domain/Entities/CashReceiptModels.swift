//
//  CashReceiptModels.swift
//  Jesuit
//
//  Domain entities for "Penerimaan Kas" (cash receipts) — the approval-workflow
//  transactions listed in the Penerimaan tab.
//

import Foundation
import SwiftUI

/// Approval state of a cash receipt. `rawValue` is the Indonesian label shown
/// in the status pill and filter tabs.
enum ReceiptStatus: String, CaseIterable, Sendable {
    case draft           = "Draft"
    case pendingApproval = "Menunggu Persetujuan"
    case approved        = "Disetujui"
    case rejected        = "Ditolak"

    /// Compact label for inline row pills (the full `rawValue` is too long for
    /// "Menunggu Persetujuan").
    var shortLabel: String {
        self == .pendingApproval ? "Menunggu" : rawValue
    }

    /// Pill / badge tint.
    var tint: Color {
        switch self {
        case .draft:           return .secondary
        case .pendingApproval: return .orange
        case .approved:        return .income
        case .rejected:        return .expense
        }
    }
}

extension ReceiptStatus {
    /// Maps a finance `cash-transactions` status code to the UI status.
    /// The API uses `posted`/`waiting`; the UI groups those as
    /// "Disetujui"/"Menunggu Persetujuan".
    init(apiStatus: String?) {
        switch apiStatus?.lowercased() {
        case "posted", "approved":          self = .approved
        case "waiting", "pending":          self = .pendingApproval
        case "rejected":                    self = .rejected
        default:                            self = .draft
        }
    }
}

/// Field the cash-transaction list is sorted by (client-side, over the loaded
/// page — the API has no sort param). Shared by the Penerimaan and Pengeluaran
/// Sort sheets.
enum ReceiptSortField: String, CaseIterable, Identifiable, Sendable {
    case createdTime  = "Waktu Dibuat"
    case lastModified = "Terakhir Diperbarui"
    case date         = "Tanggal"
    case number       = "No. Transaksi"
    case amount       = "Jumlah"
    var id: String { rawValue }
}

/// Sort direction for a `ReceiptSortField`.
enum SortDirection: Sendable {
    case newToOld, oldToNew

    var label: String { self == .newToOld ? "Terbaru ke Terlama" : "Terlama ke Terbaru" }
    /// Arrow shown on the selected sort row.
    var systemImage: String { self == .newToOld ? "arrow.down" : "arrow.up" }
    mutating func toggle() { self = self == .newToOld ? .oldToNew : .newToOld }
}

/// A single cash-receipt transaction row.
struct CashReceipt: Identifiable, Sendable {
    let id: String
    let number: String          // No. Transaksi
    let date: Date              // Tanggal
    let description: String     // Deskripsi
    let account: String         // Akun Kas/Bank
    let amount: Double          // Jumlah
    let currencyCode: String    // Mata uang (e.g. "IDR", "USD")
    let status: ReceiptStatus   // Status
    let createdAt: Date         // Dibuat Pada
    let updatedAt: Date         // Terakhir Diperbarui

    init(
        id: String = UUID().uuidString,
        number: String,
        date: Date,
        description: String,
        account: String,
        amount: Double,
        currencyCode: String = "IDR",
        status: ReceiptStatus,
        createdAt: Date,
        updatedAt: Date
    ) {
        self.id = id
        self.number = number
        self.date = date
        self.description = description
        self.account = account
        self.amount = amount
        self.currencyCode = currencyCode
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    /// Amount formatted in the transaction's currency.
    var amountText: String { amount.asCurrency(currencyCode) }
}

extension CashReceipt {
    /// Orders two receipts by the given field + direction. Used by both the
    /// Penerimaan and Pengeluaran list sorters.
    static func isOrdered(_ lhs: CashReceipt, _ rhs: CashReceipt,
                          by field: ReceiptSortField, _ direction: SortDirection) -> Bool {
        let ascending: Bool
        switch field {
        case .createdTime:  ascending = lhs.createdAt < rhs.createdAt
        case .lastModified: ascending = lhs.updatedAt < rhs.updatedAt
        case .date:         ascending = lhs.date < rhs.date
        case .number:       ascending = lhs.number.localizedStandardCompare(rhs.number) == .orderedAscending
        case .amount:       ascending = lhs.amount < rhs.amount
        }
        return direction == .oldToNew ? ascending : !ascending
    }
}

extension CashReceipt {
    /// Maps a full `CashTransactionDetailDTO` (returned by the update PUT) to the
    /// UI list entity. Account name isn't on the detail payload — callers reload
    /// the list afterwards, so a placeholder is fine here.
    init(detail dto: CashTransactionDetailDTO) {
        self.init(
            id: dto.id,
            number: dto.transactionNo ?? "-",
            date: dto.transactionDate ?? dto.createdAt ?? .now,
            description: dto.description ?? "",
            account: "-",
            amount: dto.totalAmount ?? 0,
            currencyCode: dto.currencyCode ?? "IDR",
            status: ReceiptStatus(apiStatus: dto.status),
            createdAt: dto.createdAt ?? dto.transactionDate ?? .now,
            updatedAt: dto.updatedAt ?? dto.createdAt ?? dto.transactionDate ?? .now
        )
    }

    /// Maps a finance `CashTransactionDTO` to the UI entity.
    init(dto: CashTransactionDTO) {
        self.init(
            id: dto.id,
            number: dto.number ?? "-",
            date: dto.date ?? dto.createdAt ?? .now,
            description: dto.description ?? "",
            account: dto.accountName ?? "-",
            amount: dto.amount ?? 0,
            currencyCode: dto.currencyCode ?? "IDR",
            status: ReceiptStatus(apiStatus: dto.status),
            createdAt: dto.createdAt ?? dto.date ?? .now,
            updatedAt: dto.updatedAt ?? dto.createdAt ?? dto.date ?? .now
        )
    }
}

// MARK: - Create request (POST /finance/v1/cash-transactions/submit)

/// Body for creating + submitting a cash transaction. Mirrors the web client's
/// `submit` payload: a header plus one or more journal `lines`. For the simple
/// expense form we emit a single line whose amount is the transaction total.
nonisolated struct CashTransactionRequest: Codable, Sendable {
    let branchId: String
    let transactionType: String   // "disbursement" | "receipt"
    let transactionDate: String   // "yyyy-MM-dd"
    let description: String
    let cashAccountId: String
    let currencyCode: String
    let exchangeRate: Double
    let originalAmount: Double
    let lines: [Line]

    nonisolated struct Line: Codable, Sendable {
        /// Existing server line id, sent only when editing (PUT). Without it the
        /// API treats the line as new, recreating it with a fresh id and orphaning
        /// the old line + its attachments. Nil for create (POST) / new edit lines.
        let id: String?
        let accountId: String
        let description: String
        let amount: Double
        let isPinned: Bool
        let costCenterId: String?
        let departmentId: String?
        let projectId: String?

        enum CodingKeys: String, CodingKey {
            case id, description, amount
            case accountId = "account_id"
            case isPinned = "is_pinned"
            case costCenterId = "cost_center_id"
            case departmentId = "department_id"
            case projectId = "project_id"
        }
    }

    enum CodingKeys: String, CodingKey {
        case description, lines
        case branchId = "branch_id"
        case transactionType = "transaction_type"
        case transactionDate = "transaction_date"
        case cashAccountId = "cash_account_id"
        case currencyCode = "currency_code"
        case exchangeRate = "exchange_rate"
        case originalAmount = "original_amount"
    }
}

extension CashTransactionRequest {
    /// A single draft line as entered in the form, before serialization.
    nonisolated struct DraftLine: Sendable {
        /// Server line id when editing an existing line; nil for new lines.
        let lineId: String?
        let accountId: String   // Akun Lawan (counter account)
        let description: String // Deskripsi
        let amount: Double      // Jumlah

        init(lineId: String? = nil, accountId: String, description: String, amount: Double) {
            self.lineId = lineId
            self.accountId = accountId
            self.description = description
            self.amount = amount
        }
    }

    /// Builds a multi-line expense/receipt payload from the header + lines. The
    /// header `description` mirrors the web client (first line's description).
    init(
        type: String,
        branchId: String,
        cashAccountId: String,
        date: Date,
        lines: [DraftLine],
        currencyCode: String = "IDR",
        exchangeRate: Double = 1
    ) {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        // Foreign-currency accounts carry the live rate and an `original_amount`
        // (the total back-converted to the account currency); IDR uses 1 / 0.
        // Mirrors the web client's `M ? {rate, round(totalRp/rate)} : {1, 0}`.
        let isForeign = currencyCode.uppercased() != "IDR"
        let totalRp = lines.reduce(0) { $0 + $1.amount }
        let resolvedRate = isForeign ? exchangeRate : 1
        let originalAmount = (isForeign && resolvedRate > 0)
            ? (totalRp / resolvedRate).rounded()
            : 0
        self.init(
            branchId: branchId,
            transactionType: type,
            transactionDate: df.string(from: date),
            description: lines.first?.description ?? "",
            cashAccountId: cashAccountId,
            currencyCode: currencyCode,
            exchangeRate: resolvedRate,
            originalAmount: originalAmount,
            // Only the first line is pinned. The API rejects payloads with more
            // than one pinned line ("Invalid transaction lines" / onlyOnePinned),
            // and the web client auto-pins just the first line.
            lines: lines.enumerated().map { index, line in
                Line(
                    id: line.lineId,
                    accountId: line.accountId,
                    description: line.description,
                    amount: line.amount,
                    isPinned: index == 0,
                    costCenterId: nil,
                    departmentId: nil,
                    projectId: nil
                )
            }
        )
    }
}

// MARK: - Attachment

/// A file picked for a cash transaction's `Lampiran`, uploaded as an
/// `attachments_n` part in the multipart `submit`/draft request.
struct CashAttachment: Identifiable, Sendable {
    let id = UUID()
    let filename: String
    let mimeType: String
    let data: Data

    /// Human-readable size for the thumbnail badge (e.g. "803 KB").
    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(data.count), countStyle: .file)
    }
}

// MARK: - Supporting pickers

/// A finance chart-of-accounts entry. The expense form's cash-account picker
/// uses the `cash_bank` sub-type subset.
nonisolated struct AccountDTO: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let code: String?
    let accountSubType: String?
    let currencyCode: String?
    let isActive: Bool?
    /// Current account balance, when the endpoint returns it (number or string).
    let balance: Double?

    enum CodingKeys: String, CodingKey {
        case id, name, code, balance
        case accountSubType = "account_sub_type"
        case currencyCode = "currency_code"
        case isActive = "is_active"
        case currentBalance = "current_balance"
        case endingBalance = "ending_balance"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        code = try? c.decode(String.self, forKey: .code)
        accountSubType = try? c.decode(String.self, forKey: .accountSubType)
        currencyCode = try? c.decode(String.self, forKey: .currencyCode)
        isActive = try? c.decode(Bool.self, forKey: .isActive)
        balance = AccountDTO.flexibleDouble(c, .balance)
            ?? AccountDTO.flexibleDouble(c, .currentBalance)
            ?? AccountDTO.flexibleDouble(c, .endingBalance)
    }

    /// Accepts a balance encoded as a JSON number or a numeric string.
    private static func flexibleDouble(
        _ c: KeyedDecodingContainer<CodingKeys>, _ key: CodingKeys
    ) -> Double? {
        if let d = try? c.decode(Double.self, forKey: key) { return d }
        if let s = try? c.decode(String.self, forKey: key) { return Double(s) }
        return nil
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(code, forKey: .code)
        try c.encodeIfPresent(accountSubType, forKey: .accountSubType)
        try c.encodeIfPresent(currencyCode, forKey: .currencyCode)
        try c.encodeIfPresent(isActive, forKey: .isActive)
        try c.encodeIfPresent(balance, forKey: .balance)
    }

    /// True for cash/bank accounts eligible as a transaction's cash account.
    var isCashBank: Bool { accountSubType == "cash_bank" }
}

/// A company branch (core endpoint). The form defaults to the `is_default` one.
nonisolated struct BranchDTO: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let isDefault: Bool?
    let isActive: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name
        case isDefault = "is_default"
        case isActive = "is_active"
    }
}

// MARK: - Detail (GET /finance/v1/cash-transactions/{id})

/// One journal line in a cash-transaction detail.
nonisolated struct CashTransactionLineDTO: Codable, Sendable, Identifiable {
    let id: String
    let lineNumber: Int?
    let accountId: String?
    let description: String?
    let amount: Double?
    let isPinned: Bool?
    let attachments: [CashAttachmentDTO]?

    enum CodingKeys: String, CodingKey {
        case id, description, amount, attachments
        case lineNumber = "line_number"
        case accountId = "account_id"
        case isPinned = "is_pinned"
    }
}

/// A stored attachment returned in a transaction line's `attachments` array.
nonisolated struct CashAttachmentDTO: Codable, Sendable, Identifiable {
    let id: String
    let fileName: String?
    let fileUrl: String?
    let fileSize: Int?
    let mimeType: String?

    enum CodingKeys: String, CodingKey {
        case id
        case fileName = "file_name"
        case fileUrl = "file_url"
        case fileSize = "file_size"
        case mimeType = "mime_type"
    }
}

/// Full cash-transaction detail returned by the `{id}` GET / approve / reject /
/// update endpoints. Names (account, branch, creator) are resolved client-side
/// from the accounts/branches lists and the session.
nonisolated struct CashTransactionDetailDTO: Codable, Sendable, Identifiable {
    let id: String
    let transactionNo: String?
    let transactionType: String?
    let transactionDate: Date?
    let description: String?
    let cashAccountId: String?
    let branchId: String?
    let currencyCode: String?
    let exchangeRate: Double?
    let totalAmount: Double?
    let status: String?
    let currentApprovalLevel: Int?
    let totalApprovalLevels: Int?
    let journalEntryId: String?
    let createdAt: Date?
    let createdBy: String?
    let updatedAt: Date?
    let lines: [CashTransactionLineDTO]?

    enum CodingKeys: String, CodingKey {
        case id, description, status, lines
        case transactionNo = "transaction_no"
        case transactionType = "transaction_type"
        case transactionDate = "transaction_date"
        case cashAccountId = "cash_account_id"
        case branchId = "branch_id"
        case currencyCode = "currency_code"
        case exchangeRate = "exchange_rate"
        case totalAmount = "total_amount"
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
        transactionNo = try? c.decode(String.self, forKey: .transactionNo)
        transactionType = try? c.decode(String.self, forKey: .transactionType)
        description = try? c.decode(String.self, forKey: .description)
        status = try? c.decode(String.self, forKey: .status)
        cashAccountId = try? c.decode(String.self, forKey: .cashAccountId)
        branchId = try? c.decode(String.self, forKey: .branchId)
        currencyCode = try? c.decode(String.self, forKey: .currencyCode)
        exchangeRate = (try? c.decode(Double.self, forKey: .exchangeRate))
            ?? (try? c.decode(String.self, forKey: .exchangeRate)).flatMap(Double.init)
        journalEntryId = try? c.decode(String.self, forKey: .journalEntryId)
        createdBy = try? c.decode(String.self, forKey: .createdBy)
        currentApprovalLevel = try? c.decode(Int.self, forKey: .currentApprovalLevel)
        totalApprovalLevels = try? c.decode(Int.self, forKey: .totalApprovalLevels)
        totalAmount = (try? c.decode(Double.self, forKey: .totalAmount))
            ?? (try? c.decode(String.self, forKey: .totalAmount)).flatMap(Double.init)
        lines = try? c.decode([CashTransactionLineDTO].self, forKey: .lines)

        func date(_ key: CodingKeys) -> Date? {
            guard let str = try? c.decode(String.self, forKey: key), !str.isEmpty else { return nil }
            let iso = ISO8601DateFormatter()
            iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let d = iso.date(from: str) { return d }
            iso.formatOptions = [.withInternetDateTime]
            if let d = iso.date(from: str) { return d }
            let ymd = DateFormatter(); ymd.locale = Locale(identifier: "en_US_POSIX"); ymd.dateFormat = "yyyy-MM-dd"
            return ymd.date(from: str)
        }
        transactionDate = date(.transactionDate)
        createdAt = date(.createdAt)
        updatedAt = date(.updatedAt)
    }
}

nonisolated struct CashTransactionDetailResponse: Codable, Sendable {
    let data: CashTransactionDetailDTO?
    let message: String?
}

/// A stored attachment shown in the detail sheet (downloaded from `fileUrl`).
struct CashLineAttachment: Identifiable, Sendable {
    let id: String
    let fileName: String
    let fileUrl: String
    let fileSize: Int
    let mimeType: String

    /// True for image attachments (rendered as a thumbnail rather than a doc icon).
    var isImage: Bool { mimeType.hasPrefix("image/") }

    /// Human-readable size for the thumbnail badge (e.g. "803 KB").
    var sizeLabel: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}

/// One line in the detail's "Detail Lines" table (names resolved client-side).
struct CashReceiptLine: Identifiable, Sendable {
    let id: String
    let lineNumber: Int
    let accountId: String?
    let accountName: String
    let description: String
    let amount: Double
    let currencyCode: String
    let isPinned: Bool
    let attachments: [CashLineAttachment]
}

/// Full cash-receipt detail for the detail sheet.
struct CashReceiptDetail: Sendable {
    let id: String
    let number: String
    let date: Date
    let description: String
    let cashAccountId: String?
    let cashAccountName: String
    let branchName: String
    let total: Double
    let currencyCode: String
    /// Stored `base`→IDR rate for foreign-currency transactions (1 for IDR).
    let exchangeRate: Double
    let status: ReceiptStatus
    /// Raw API status (e.g. "draft", "waiting", "posted", "rejected"), used for
    /// action gating so unmapped values don't fall back to a permissive default.
    let rawStatus: String
    let approvalLevel: Int?
    let totalApprovalLevels: Int?
    let hasJournal: Bool
    let createdAt: Date
    let createdById: String?
    let updatedAt: Date
    let lines: [CashReceiptLine]
}

// MARK: - Approve / reject request bodies

nonisolated struct ApproveRequest: Codable, Sendable {
    let comment: String
}

nonisolated struct RejectRequest: Codable, Sendable {
    let reason: String
}

// MARK: - DTOs (GET /finance/v1/cash-transactions?transaction_type=receipt)

/// Per-status counts returned in `meta.counts` for the cash-transactions list.
/// Drives the filter-tab badges without a second round-trip.
nonisolated struct CashTransactionCounts: Codable, Sendable {
    let all: Int?
    let draft: Int?
    let posted: Int?
    let rejected: Int?
    let waiting: Int?
}

/// A single `cash-transactions` item.
///
/// The captured HAR returned an empty list, so — as with `ContactDTO` — every
/// field beyond `id` is decoded leniently and tolerant of both flat
/// (`cash_account_name`) and nested (`cash_account: { name }`) shapes.
nonisolated struct CashTransactionDTO: Codable, Sendable, Identifiable {
    let id: String
    let number: String?
    let date: Date?
    let description: String?
    let accountName: String?
    let amount: Double?
    let status: String?
    let currencyCode: String?
    let createdAt: Date?
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, amount, status, description
        case transactionNumber = "transaction_number"
        case transactionNo     = "transaction_no"
        case referenceNumber   = "reference_number"
        case transactionDate   = "transaction_date"
        case currencyCode      = "currency_code"
        case createdAt         = "created_at"
        case updatedAt         = "updated_at"
        case totalAmount       = "total_amount"
        case originalAmount    = "original_amount"
        case cashAccountName   = "cash_account_name"
        case cashAccount       = "cash_account"
        case createdByName     = "created_by_name"
        case account
    }

    private enum AccountKeys: String, CodingKey {
        case name
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        number = (try? c.decode(String.self, forKey: .transactionNo))
            ?? (try? c.decode(String.self, forKey: .transactionNumber))
            ?? (try? c.decode(String.self, forKey: .referenceNumber))
        description = try? c.decode(String.self, forKey: .description)
        status = try? c.decode(String.self, forKey: .status)
        currencyCode = try? c.decode(String.self, forKey: .currencyCode)
        // API sends `total_amount`; fall back to `original_amount`/`amount`.
        amount = CashTransactionDTO.decodeFlexibleDouble(c, forKey: .totalAmount)
            ?? CashTransactionDTO.decodeFlexibleDouble(c, forKey: .originalAmount)
            ?? CashTransactionDTO.decodeFlexibleDouble(c, forKey: .amount)
        date = CashTransactionDTO.decodeFlexibleDate(c, forKey: .transactionDate)
        createdAt = CashTransactionDTO.decodeFlexibleDate(c, forKey: .createdAt)
        updatedAt = CashTransactionDTO.decodeFlexibleDate(c, forKey: .updatedAt)

        // Account may arrive flat (cash_account_name) or nested under
        // `cash_account` / `account`.
        if let name = try? c.decode(String.self, forKey: .cashAccountName) {
            accountName = name
        } else if let nested = try? c.nestedContainer(keyedBy: AccountKeys.self, forKey: .cashAccount) {
            accountName = try? nested.decode(String.self, forKey: .name)
        } else if let nested = try? c.nestedContainer(keyedBy: AccountKeys.self, forKey: .account) {
            accountName = try? nested.decode(String.self, forKey: .name)
        } else {
            accountName = nil
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(number, forKey: .transactionNumber)
        try c.encodeIfPresent(description, forKey: .description)
        try c.encodeIfPresent(status, forKey: .status)
        try c.encodeIfPresent(amount, forKey: .amount)
        try c.encodeIfPresent(accountName, forKey: .cashAccountName)
    }

    /// Accepts an amount encoded as a JSON number or a numeric string.
    private static func decodeFlexibleDouble(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Double? {
        if let value = try? container.decode(Double.self, forKey: key) { return value }
        if let str = try? container.decode(String.self, forKey: key) { return Double(str) }
        return nil
    }

    /// Accepts an ISO-8601 (with or without fractional seconds) or `yyyy-MM-dd`
    /// date string.
    private static func decodeFlexibleDate(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Date? {
        guard let str = try? container.decode(String.self, forKey: key), !str.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: str) { return date }
        iso.formatOptions = [.withInternetDateTime]
        if let date = iso.date(from: str) { return date }
        let ymd = DateFormatter()
        ymd.locale = Locale(identifier: "en_US_POSIX")
        ymd.dateFormat = "yyyy-MM-dd"
        return ymd.date(from: str)
    }
}
