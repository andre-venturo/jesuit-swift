//
//  EditProfilePresenter.swift
//  Jesuit
//
//  Backs the "Ubah Profil" sheet: prefills from the session and calls
//  `PUT /users/me`.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class EditProfilePresenter {
    private let authRepository: AuthRepositoryProtocol
    private let session: AuthSession

    init(authRepository: AuthRepositoryProtocol, session: AuthSession) {
        self.authRepository = authRepository
        self.session = session
    }

    var fullName = ""
    var phone = ""

    private(set) var isSaving = false
    var errorMessage: String?

    /// Read-only identity shown for context (changed only by an admin).
    var email: String { session.user?.email ?? "" }
    var username: String { session.user?.username ?? "" }

    /// Initials for the avatar placeholder (e.g. "AZ" from "Andre ZZ").
    var initials: String {
        let base = fullName.isEmpty ? (session.user?.fullName ?? "") : fullName
        return base.split(separator: " ").prefix(2)
            .compactMap { $0.first }.map(String.init).joined().uppercased()
    }

    /// Seeds the form from the current session. Call on sheet appear.
    func prefill() {
        fullName = session.user?.fullName ?? ""
        phone = session.user?.phone ?? ""
        errorMessage = nil
    }

    var isValid: Bool {
        !fullName.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Submits the profile update. Returns `true` on success so the caller can
    /// dismiss; the session is refreshed with the canonical profile.
    func submit() async -> Bool {
        guard isValid, !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            let me = try await authRepository.updateProfile(
                fullName: fullName.trimmingCharacters(in: .whitespaces),
                phone: phone.trimmingCharacters(in: .whitespaces)
            )
            session.update(with: me)
            return true
        } catch let error as NetworkError {
            if case let .serverError(_, message?) = error, !message.isEmpty {
                errorMessage = message
            } else {
                errorMessage = "Gagal memperbarui profil."
            }
            return false
        } catch {
            errorMessage = "Gagal memperbarui profil."
            return false
        }
    }
}
