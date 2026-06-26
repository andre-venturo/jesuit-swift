//
//  AssetModels.swift
//  Jesuit
//
//  Domain entities + DTOs for "Aset" (fixed assets). Backed by
//  /finance/v1/assets and /finance/v1/asset-categories. Plain CRUD — no
//  approval workflow. Reuses `CashAttachment`/`CashLineAttachment`/
//  `CashAttachmentDTO` for photos and `BranchDTO` for the branch picker.
//

import Foundation
import SwiftUI

// MARK: - Status

/// Lifecycle status of an asset. `rawValue` is the Indonesian status label.
enum AssetStatus: String, CaseIterable, Sendable {
    case active        = "Aktif"
    case inMaintenance = "Pemeliharaan"
    case disposed      = "Dilepas"
    case sold          = "Terjual"
    case rented        = "Disewakan"

    init(apiStatus: String?) {
        switch apiStatus?.lowercased() {
        case "in_maintenance": self = .inMaintenance
        case "disposed":       self = .disposed
        case "sold":           self = .sold
        case "rented":         self = .rented
        default:               self = .active
        }
    }

    /// API code (`active`/`in_maintenance`/…) for list-filter params.
    var apiCode: String {
        switch self {
        case .active:        return "active"
        case .inMaintenance: return "in_maintenance"
        case .disposed:      return "disposed"
        case .sold:          return "sold"
        case .rented:        return "rented"
        }
    }

    var tint: Color {
        switch self {
        case .active:        return .income
        case .inMaintenance: return .orange
        case .rented:        return .accent
        case .sold:          return .expense
        case .disposed:      return .secondary
        }
    }
}

// MARK: - List row

/// A single asset row for the Aset list.
struct Asset: Identifiable, Sendable {
    let id: String
    let code: String            // asset_code
    let name: String            // asset_name
    let categoryId: String?
    let categoryName: String    // resolved, "Lain-lain" when null
    let branchName: String
    let location: String
    let quantity: Int
    let purchaseValue: Double
    let purchaseDate: Date?
    let status: AssetStatus
    let photoUrl: String?
    let createdAt: Date

    var purchaseValueText: String { purchaseValue.asRupiah }

    init(dto: AssetDTO) {
        id = dto.id
        code = dto.assetCode ?? "-"
        name = dto.assetName ?? "-"
        categoryId = dto.category?.id
        categoryName = dto.category?.name ?? "Lain-lain"
        branchName = dto.branch?.name ?? "—"
        location = dto.location ?? ""
        quantity = dto.quantity ?? 1
        purchaseValue = dto.purchaseValue ?? 0
        purchaseDate = dto.purchaseDate
        status = AssetStatus(apiStatus: dto.status)
        photoUrl = dto.photo?.fileUrl
        createdAt = dto.createdAt ?? .now
    }
}

// MARK: - Detail

/// Full asset detail for the detail sheet (photos fetched separately).
struct AssetDetail: Sendable {
    let id: String
    let code: String
    let name: String
    let categoryId: String?
    let categoryName: String
    let branchId: String?
    let branchName: String
    let location: String
    let note: String
    let quantity: Int
    let purchaseValue: Double
    let purchaseDate: Date?
    let startUseDate: Date?
    let assetAgeYear: Int?
    let assetAgeMonth: Int?
    let isIntangible: Bool
    let depreciationMethod: String
    let salvageValue: Double
    let depreciationRate: Double?
    let status: AssetStatus
    let createdByName: String
    let createdAt: Date

    init(dto: AssetDTO) {
        id = dto.id
        code = dto.assetCode ?? "-"
        name = dto.assetName ?? "-"
        categoryId = dto.category?.id
        categoryName = dto.category?.name ?? "Lain-lain"
        branchId = dto.branch?.id
        branchName = dto.branch?.name ?? "—"
        location = dto.location ?? ""
        note = dto.note ?? ""
        quantity = dto.quantity ?? 1
        purchaseValue = dto.purchaseValue ?? 0
        purchaseDate = dto.purchaseDate
        startUseDate = dto.startUseDate
        assetAgeYear = dto.assetAgeYear
        assetAgeMonth = dto.assetAgeMonth
        isIntangible = dto.isIntangible ?? false
        depreciationMethod = dto.depreciationMethod ?? "straight-line"
        salvageValue = dto.salvageValue ?? 0
        depreciationRate = dto.depreciationRate
        status = AssetStatus(apiStatus: dto.status)
        createdByName = dto.createdBy?.name ?? "—"
        createdAt = dto.createdAt ?? .now
    }
}

// MARK: - Category

/// An asset category, used for the form picker and list filter.
struct AssetCategory: Identifiable, Sendable {
    let id: String
    let name: String
    let codePrefix: String
    let assetCount: Int

    init(dto: AssetCategoryDTO) {
        id = dto.id
        name = dto.name
        codePrefix = dto.codePrefix ?? ""
        assetCount = dto.assetCount ?? 0
    }
}

// MARK: - Create / update request

/// Body for creating / updating an asset. The depreciation fields aren't edited
/// in the mobile form — they're seeded from the existing asset on edit and sent
/// as defaults on create (mirrors the web form's hidden fields). Nil optionals
/// are omitted; the BE treats an omitted `category_id` as the "Lain-lain" bucket.
nonisolated struct CreateAssetRequest: Codable, Sendable {
    let assetName: String
    let categoryId: String?
    let branchId: String
    let purchaseValue: Double
    let quantity: Int
    let purchaseDate: String?
    let location: String?
    let note: String?
    let startUseDate: String?
    let assetAgeYear: Int?
    let assetAgeMonth: Int?
    let isIntangible: Bool
    let depreciationMethod: String
    let salvageValue: Double
    let depreciationRate: Double?

    enum CodingKeys: String, CodingKey {
        case location, note, quantity
        case assetName = "asset_name"
        case categoryId = "category_id"
        case branchId = "branch_id"
        case purchaseValue = "purchase_value"
        case purchaseDate = "purchase_date"
        case startUseDate = "start_use_date"
        case assetAgeYear = "asset_age_year"
        case assetAgeMonth = "asset_age_month"
        case isIntangible = "is_intangible"
        case depreciationMethod = "depreciation_method"
        case salvageValue = "salvage_value"
        case depreciationRate = "depreciation_rate"
    }
}

// MARK: - DTOs

nonisolated struct AssetListResponse: Codable, Sendable {
    let data: [AssetDTO]?
    let message: String?
    let meta: PaginatedResponse<AssetDTO>.Meta?
}

nonisolated struct AssetDetailResponse: Codable, Sendable {
    let data: AssetDTO?
    let message: String?
}

nonisolated struct AssetCategoriesResponse: Codable, Sendable {
    let data: [AssetCategoryDTO]?
    let message: String?
}

/// Envelope for `GET /assets/{id}/attachments`: `{ data: [CashAttachmentDTO] }`.
nonisolated struct AssetAttachmentsResponse: Codable, Sendable {
    let data: [CashAttachmentDTO]?
    let message: String?
}

nonisolated struct AssetCategoryDTO: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let codePrefix: String?
    let assetCount: Int?

    enum CodingKeys: String, CodingKey {
        case id, name
        case codePrefix = "code_prefix"
        case assetCount = "asset_count"
    }
}

/// Nested category/branch/created-by references on an asset.
nonisolated struct AssetRefDTO: Codable, Sendable {
    let id: String?
    let name: String?
}

/// One asset item. The list and detail endpoints return the same shape. Decoded
/// leniently (number-or-string amounts, ISO/`yyyy-MM-dd` dates).
nonisolated struct AssetDTO: Codable, Sendable, Identifiable {
    let id: String
    let assetCode: String?
    let assetName: String?
    let category: AssetRefDTO?
    let branch: AssetRefDTO?
    let location: String?
    let note: String?
    let quantity: Int?
    let purchaseValue: Double?
    let purchaseDate: Date?
    let startUseDate: Date?
    let assetAgeYear: Int?
    let assetAgeMonth: Int?
    let isIntangible: Bool?
    let depreciationMethod: String?
    let salvageValue: Double?
    let depreciationRate: Double?
    let status: String?
    let photo: CashAttachmentDTO?
    let createdBy: AssetRefDTO?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, category, branch, location, note, quantity, status, photo
        case assetCode = "asset_code"
        case assetName = "asset_name"
        case purchaseValue = "purchase_value"
        case purchaseDate = "purchase_date"
        case startUseDate = "start_use_date"
        case assetAgeYear = "asset_age_year"
        case assetAgeMonth = "asset_age_month"
        case isIntangible = "is_intangible"
        case depreciationMethod = "depreciation_method"
        case salvageValue = "salvage_value"
        case depreciationRate = "depreciation_rate"
        case createdBy = "created_by"
        case createdAt = "created_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        assetCode = try? c.decode(String.self, forKey: .assetCode)
        assetName = try? c.decode(String.self, forKey: .assetName)
        category = try? c.decode(AssetRefDTO.self, forKey: .category)
        branch = try? c.decode(AssetRefDTO.self, forKey: .branch)
        location = try? c.decode(String.self, forKey: .location)
        note = try? c.decode(String.self, forKey: .note)
        quantity = try? c.decode(Int.self, forKey: .quantity)
        status = try? c.decode(String.self, forKey: .status)
        photo = try? c.decode(CashAttachmentDTO.self, forKey: .photo)
        isIntangible = try? c.decode(Bool.self, forKey: .isIntangible)
        depreciationMethod = try? c.decode(String.self, forKey: .depreciationMethod)
        assetAgeYear = try? c.decode(Int.self, forKey: .assetAgeYear)
        assetAgeMonth = try? c.decode(Int.self, forKey: .assetAgeMonth)
        createdBy = try? c.decode(AssetRefDTO.self, forKey: .createdBy)
        purchaseValue = Self.flexibleDouble(c, .purchaseValue)
        salvageValue = Self.flexibleDouble(c, .salvageValue)
        depreciationRate = Self.flexibleDouble(c, .depreciationRate)
        purchaseDate = Self.flexibleDate(c, .purchaseDate)
        startUseDate = Self.flexibleDate(c, .startUseDate)
        createdAt = Self.flexibleDate(c, .createdAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(assetName, forKey: .assetName)
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
