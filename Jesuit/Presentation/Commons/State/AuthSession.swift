//
//  AuthSession.swift
//  Jesuit
//
//  Shared, observable holder for the signed-in user. Presenters read and
//  write this so the UI (e.g. the More tab) reflects the live account.
//

import Foundation
import Observation

/// Permission strings returned by `/auth/me` in `resource:action` form.
/// Centralised here so call sites stay typo-proof instead of raw literals.
enum Permission {
    static let cashCreate    = "finance.cash_transactions:create"
    static let cashUpdate    = "finance.cash_transactions:update"
    static let cashDelete    = "finance.cash_transactions:delete"
    static let cashApprove   = "finance.cash_transactions:approve"
    static let contactCreate = "finance.contacts:create"
}

@Observable
@MainActor
final class AuthSession {
    var user: AuthUser?
    var company: AuthCompany?
    var roles: [String] = []
    /// Granular `resource:action` grants from `/auth/me`.
    var permissions: Set<String> = []

    var isAuthenticated: Bool { user != nil }

    var displayName: String { user?.fullName ?? "Guest" }
    var organization: String { company?.name ?? "-" }

    /// Signed-in user's id, for "created by me" / approver checks.
    var userId: String? { user?.id }

    /// True when the signed-in user can approve/reject/manage transactions.
    var isAdministrator: Bool {
        roles.contains { $0.lowercased() == "administrator" }
    }

    /// True when the user holds `resource:action`, or is an administrator.
    /// Administrators implicitly hold every permission, which also covers
    /// `/me` payloads that omit the permissions array (older tokens).
    func can(_ permission: String) -> Bool {
        isAdministrator || permissions.contains(permission)
    }

    func update(with me: AuthMe) {
        user = me.user
        company = me.company
        roles = me.roles ?? []
        permissions = Set(me.permissions ?? [])
    }

    func clear() {
        user = nil
        company = nil
        roles = []
        permissions = []
    }
}
