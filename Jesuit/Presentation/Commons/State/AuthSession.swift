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

    var isAuthenticated: Bool { user != nil }

    var displayName: String { user?.fullName ?? "Guest" }
    var organization: String { company?.name ?? "-" }

    func update(with me: AuthMe) {
        user = me.user
        company = me.company
    }

    func clear() {
        user = nil
        company = nil
    }
}
