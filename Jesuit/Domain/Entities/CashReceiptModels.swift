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

/// A single cash-receipt transaction row.
struct CashReceipt: Identifiable, Sendable {
    let id: String
    let number: String          // No. Transaksi
    let date: Date              // Tanggal
    let description: String     // Deskripsi
    let account: String         // Akun Kas/Bank
    let amount: Double          // Jumlah
    let status: ReceiptStatus   // Status
    let createdAt: Date         // Dibuat Pada

    init(
        id: String = UUID().uuidString,
        number: String,
        date: Date,
        description: String,
        account: String,
        amount: Double,
        status: ReceiptStatus,
        createdAt: Date
    ) {
        self.id = id
        self.number = number
        self.date = date
        self.description = description
        self.account = account
        self.amount = amount
        self.status = status
        self.createdAt = createdAt
    }
}

extension CashReceipt {
    /// Maps a finance `CashTransactionDTO` to the UI entity.
    init(dto: CashTransactionDTO) {
        self.init(
            id: dto.id,
            number: dto.number ?? "-",
            date: dto.date ?? dto.createdAt ?? .now,
            description: dto.description ?? "",
            account: dto.accountName ?? "-",
            amount: dto.amount ?? 0,
            status: ReceiptStatus(apiStatus: dto.status),
            createdAt: dto.createdAt ?? dto.date ?? .now
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
        let accountId: String
        let description: String
        let amount: Double
        let isPinned: Bool
        let costCenterId: String?
        let departmentId: String?
        let projectId: String?

        enum CodingKeys: String, CodingKey {
            case description, amount
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
        let accountId: String   // Akun Lawan (counter account)
        let description: String // Deskripsi
        let amount: Double      // Jumlah
    }

    /// Builds a multi-line expense/receipt payload from the header + lines. The
    /// header `description` mirrors the web client (first line's description).
    init(
        type: String,
        branchId: String,
        cashAccountId: String,
        date: Date,
        lines: [DraftLine],
        currencyCode: String = "IDR"
    ) {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd"
        self.init(
            branchId: branchId,
            transactionType: type,
            transactionDate: df.string(from: date),
            description: lines.first?.description ?? "",
            cashAccountId: cashAccountId,
            currencyCode: currencyCode,
            exchangeRate: 1,
            originalAmount: 0,
            lines: lines.map { line in
                Line(
                    accountId: line.accountId,
                    description: line.description,
                    amount: line.amount,
                    isPinned: true,
                    costCenterId: nil,
                    departmentId: nil,
                    projectId: nil
                )
            }
        )
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

    enum CodingKeys: String, CodingKey {
        case id, name, code
        case accountSubType = "account_sub_type"
        case currencyCode = "currency_code"
        case isActive = "is_active"
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
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, amount, status, description
        case transactionNumber = "transaction_number"
        case transactionNo     = "transaction_no"
        case referenceNumber   = "reference_number"
        case transactionDate   = "transaction_date"
        case createdAt         = "created_at"
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
        // API sends `total_amount`; fall back to `original_amount`/`amount`.
        amount = CashTransactionDTO.decodeFlexibleDouble(c, forKey: .totalAmount)
            ?? CashTransactionDTO.decodeFlexibleDouble(c, forKey: .originalAmount)
            ?? CashTransactionDTO.decodeFlexibleDouble(c, forKey: .amount)
        date = CashTransactionDTO.decodeFlexibleDate(c, forKey: .transactionDate)
        createdAt = CashTransactionDTO.decodeFlexibleDate(c, forKey: .createdAt)

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
