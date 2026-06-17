//
//  AuthModels.swift
//  Jesuit
//
//  Request/response DTOs for the wizhub auth endpoints
//  (POST /auth/signin, /auth/signup, /auth/logout and GET /auth/me).
//

import Foundation

// These DTOs cross into the `NetworkService` actor as `Sendable` generic
// parameters, so their Codable conformances must be `nonisolated` (the module
// default isolation is MainActor).

// MARK: - Requests

nonisolated struct SignInRequest: Encodable, Sendable {
    let login: String
    let password: String
}

nonisolated struct SignUpRequest: Encodable, Sendable {
    let email: String
    let username: String
    let password: String
    let fullName: String
    let phone: String
    let companyName: String

    enum CodingKeys: String, CodingKey {
        case email, username, password, phone
        case fullName = "full_name"
        case companyName = "company_name"
    }
}

nonisolated struct LogoutRequest: Encodable, Sendable {
    let refreshToken: String

    enum CodingKeys: String, CodingKey {
        case refreshToken = "refresh_token"
    }
}

nonisolated struct SwitchCompanyRequest: Encodable, Sendable {
    let companyId: String

    enum CodingKeys: String, CodingKey {
        case companyId = "company_id"
    }
}

nonisolated struct ChangePasswordRequest: Encodable, Sendable {
    let currentPassword: String
    let newPassword: String

    enum CodingKeys: String, CodingKey {
        case currentPassword = "current_password"
        case newPassword = "new_password"
    }
}

nonisolated struct UpdateProfileRequest: Encodable, Sendable {
    let fullName: String
    let phone: String

    enum CodingKeys: String, CodingKey {
        case fullName = "full_name"
        case phone
    }
}

// MARK: - Companies (GET /auth/companies, POST /auth/switch-company)

/// One company the signed-in user can act under. The header switcher lists these
/// (a holding plus its subsidiaries); `isPrimary` marks the default.
nonisolated struct CompanyDTO: Codable, Sendable, Identifiable {
    let id: String
    let name: String
    let type: String?
    let parentId: String?
    let isPrimary: Bool?
    let isOwner: Bool?
    let roleName: String?

    enum CodingKeys: String, CodingKey {
        case id, name, type
        case parentId = "parent_id"
        case isPrimary = "is_primary"
        case isOwner = "is_owner"
        case roleName = "role_name"
    }

    /// True for the top-level holding company (no parent).
    var isHolding: Bool { (parentId ?? "").isEmpty }

    /// Localised label for the company `type` (e.g. `Holding`, `Anak Perusahaan`).
    var typeLabel: String {
        switch (type ?? "").lowercased() {
        case "holding": return "Holding"
        case "subsidiary": return "Anak Perusahaan"
        default: return type?.capitalized ?? "Perusahaan"
        }
    }

    /// Switcher row subtitle: `Type • Role`, dropping the role when absent.
    var subtitle: String {
        if let role = roleName, !role.isEmpty {
            return "\(typeLabel) • \(role)"
        }
        return typeLabel
    }
}

nonisolated struct CompaniesResponse: Codable, Sendable {
    let data: [CompanyDTO]?
}

/// Company kind for the create form's "Tipe" picker. A `holding` sits at the
/// top with no parent; a `subsidiary` must reference a holding via `parent_id`.
nonisolated enum CompanyType: String, CaseIterable, Identifiable, Sendable {
    case holding
    case subsidiary

    var id: String { rawValue }

    /// Localised label for the picker (e.g. `Holding`, `Anak Perusahaan`).
    var label: String {
        switch self {
        case .holding: return "Holding"
        case .subsidiary: return "Anak Perusahaan"
        }
    }
}

/// `POST /companies` body. `parentId` is required for a subsidiary and must be
/// `nil` for a holding.
nonisolated struct CreateCompanyRequest: Encodable, Sendable {
    let name: String
    let type: String
    let parentId: String?

    enum CodingKeys: String, CodingKey {
        case name, type
        case parentId = "parent_id"
    }
}

nonisolated struct CreateCompanyResponse: Codable, Sendable {
    let data: CompanyDTO?
}

// MARK: - Token payload

/// Tokens returned by `signin` / `signup`. The backend's exact key names are
/// decoded tolerantly because the captured HAR delivered them via httpOnly
/// cookies (stripped from the export) rather than a visible JSON body.
nonisolated struct AuthTokens: Codable, Sendable {
    let accessToken: String
    let refreshToken: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: AnyCodingKey.self)

        func value(for keys: [String]) -> String? {
            for key in keys {
                if let coding = AnyCodingKey(stringValue: key),
                   let str = try? container.decode(String.self, forKey: coding),
                   !str.isEmpty {
                    return str
                }
            }
            return nil
        }

        guard let access = value(for: ["access_token", "accessToken", "token", "access"]) else {
            throw DecodingError.dataCorrupted(
                .init(codingPath: decoder.codingPath, debugDescription: "Missing access token")
            )
        }
        accessToken = access
        // Some backends omit a refresh token; fall back to the access token so
        // the keychain contract (which requires both) is still satisfied.
        refreshToken = value(for: ["refresh_token", "refreshToken", "refresh"]) ?? access
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: AnyCodingKey.self)
        try container.encode(accessToken, forKey: AnyCodingKey(stringValue: "access_token")!)
        try container.encode(refreshToken, forKey: AnyCodingKey(stringValue: "refresh_token")!)
    }
}

// MARK: - /auth/me

nonisolated struct AuthMe: Codable, Sendable {
    let user: AuthUser
    let company: AuthCompany?
    let roles: [String]?
    let permissions: [String]?
}

nonisolated struct AuthUser: Codable, Sendable {
    let id: String
    let email: String
    let username: String
    let fullName: String
    /// Optional — present on `/users/me` but not always on the signin payload.
    let phone: String?

    enum CodingKeys: String, CodingKey {
        case id, email, username, phone
        case fullName = "full_name"
    }
}

nonisolated struct AuthCompany: Codable, Sendable {
    let id: String
    let name: String
}

// MARK: - Helpers

/// A `CodingKey` that accepts any string, used to probe alternative JSON keys.
nonisolated struct AnyCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
