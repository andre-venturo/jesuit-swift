//
//  AuthSession.swift
//  Jesuit
//
//  Shared, observable holder for the signed-in user. Presenters read and
//  write this so the UI (e.g. the More tab) reflects the live account.
//

import Foundation
import Observation

@Observable
@MainActor
final class AuthSession {
    var user: AuthUser?
    var company: AuthCompany?
    var roles: [String] = []

    var isAuthenticated: Bool { user != nil }

    var displayName: String { user?.fullName ?? "Guest" }
    var organization: String { company?.name ?? "-" }

    /// Signed-in user's id, for "created by me" / approver checks.
    var userId: String? { user?.id }

    /// True when the signed-in user can approve/reject/manage transactions.
    var isAdministrator: Bool {
        roles.contains { $0.lowercased() == "administrator" }
    }

    func update(with me: AuthMe) {
        user = me.user
        company = me.company
        roles = me.roles ?? []
    }

    func clear() {
        user = nil
        company = nil
        roles = []
    }
}
