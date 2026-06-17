//
//  RegisterPresenter.swift
//  Jesuit
//
//  Created by admin on 25/11/25.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class RegisterPresenter {
    var nameText: String = ""
    var usernameText: String = ""
    var emailText: String = ""
    var phoneText: String = ""
    var companyText: String = ""
    var passText: String = ""
    var errorMessage: String?
    var isLoading: Bool = false

    private let authRepository: AuthRepositoryProtocol
    private let session: AuthSession

    init(authRepository: AuthRepositoryProtocol, session: AuthSession) {
        self.authRepository = authRepository
        self.session = session
    }

    /// Validates the form. Returns true when registration may proceed. Mirrors
    /// the web signup: phone is optional, no confirm-password field.
    func validate() -> Bool {
        guard !nameText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Masukkan nama lengkap Anda."
            return false
        }
        let email = emailText.trimmingCharacters(in: .whitespaces)
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "Masukkan alamat email yang valid."
            return false
        }
        guard !usernameText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Pilih sebuah username."
            return false
        }
        guard !companyText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Masukkan nama perusahaan."
            return false
        }
        guard passText.count >= 6 else {
            errorMessage = "Kata sandi minimal 6 karakter."
            return false
        }
        errorMessage = nil
        return true
    }

    /// Registers the account. Returns true on success so the view can navigate.
    func register() async -> Bool {
        guard validate() else { return false }
        isLoading = true
        defer { isLoading = false }

        let request = SignUpRequest(
            email: emailText.trimmingCharacters(in: .whitespaces),
            username: usernameText.trimmingCharacters(in: .whitespaces),
            password: passText,
            fullName: nameText.trimmingCharacters(in: .whitespaces),
            phone: phoneText.trimmingCharacters(in: .whitespaces),
            companyName: companyText.trimmingCharacters(in: .whitespaces)
        )

        do {
            let me = try await authRepository.signUp(request)
            session.update(with: me)
            return true
        } catch {
            errorMessage = Self.registerMessage(for: error)
            return false
        }
    }

    private static func registerMessage(for error: Error) -> String {
        if case NetworkError.serverError(409, _) = error {
            return "Akun dengan email atau username ini sudah terdaftar."
        }
        return LoginPresenter.message(for: error)
    }
}
