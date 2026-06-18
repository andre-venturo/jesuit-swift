//
//  ActivityLogModels.swift
//  Jesuit
//
//  DTOs + UI entity for a cash transaction's activity log (the "Riwayat" tab),
//  backed by GET /core/v1/audit-logs?reff_type=finance.cash_transactions&reff_id={id}.
//

import Foundation

// MARK: - Audit log DTO

/// One audit-log entry for a document. The captured response includes more keys
/// (ip_address, user_agent, request_id, metadata, …); we decode only what the
/// timeline shows. `created_at` falls back to `occurred_at`.
nonisolated struct AuditLogDTO: Codable, Sendable, Identifiable {
    let id: String
    let action: String?
    let summary: String?
    let actorName: String?
    let actorRole: String?
    let reffNo: String?
    let createdAt: Date?

    enum CodingKeys: String, CodingKey {
        case id, action, summary
        case actorName = "actor_name"
        case actorRole = "actor_role"
        case reffNo = "reff_no"
        case createdAt = "created_at"
        case occurredAt = "occurred_at"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        action = try? c.decode(String.self, forKey: .action)
        summary = try? c.decode(String.self, forKey: .summary)
        actorName = try? c.decode(String.self, forKey: .actorName)
        actorRole = try? c.decode(String.self, forKey: .actorRole)
        reffNo = try? c.decode(String.self, forKey: .reffNo)
        createdAt = AuditLogDTO.decodeFlexibleDate(c, forKey: .createdAt)
            ?? AuditLogDTO.decodeFlexibleDate(c, forKey: .occurredAt)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encodeIfPresent(action, forKey: .action)
        try c.encodeIfPresent(summary, forKey: .summary)
        try c.encodeIfPresent(actorName, forKey: .actorName)
        try c.encodeIfPresent(actorRole, forKey: .actorRole)
        try c.encodeIfPresent(reffNo, forKey: .reffNo)
    }

    /// Accepts an ISO-8601 (with or without fractional seconds) date string.
    private static func decodeFlexibleDate(
        _ container: KeyedDecodingContainer<CodingKeys>,
        forKey key: CodingKeys
    ) -> Date? {
        guard let str = try? container.decode(String.self, forKey: key), !str.isEmpty else { return nil }
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = iso.date(from: str) { return date }
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: str)
    }
}

// MARK: - UI entity

/// One row in the detail sheet's "Riwayat" timeline.
struct ActivityEntry: Identifiable, Sendable {
    let id: String
    let title: String   // human-readable action (summary, or mapped action)
    let actor: String   // "By <name>" — empty when unknown
    let date: Date?

    init(dto: AuditLogDTO) {
        id = dto.id
        title = dto.summary ?? ActivityEntry.label(for: dto.action)
        actor = (dto.actorName?.isEmpty == false) ? "Oleh \(dto.actorName!)" : ""
        date = dto.createdAt
    }

    /// Indonesian fallback label when the API omits a `summary`.
    private static func label(for action: String?) -> String {
        switch action?.lowercased() {
        case "created":   return "Transaksi dibuat"
        case "submitted": return "Disubmit untuk approval"
        case "approved":  return "Disetujui"
        case "rejected":  return "Ditolak"
        case "updated":   return "Diperbarui"
        case "deleted":   return "Dihapus"
        default:          return action?.capitalized ?? "Aktivitas"
        }
    }
}
