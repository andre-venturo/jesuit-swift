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
    var confirmText: String = ""
    var errorMessage: String?
    var isLoading: Bool = false

    private let authRepository: AuthRepositoryProtocol
    private let session: AuthSession

    init(authRepository: AuthRepositoryProtocol, session: AuthSession) {
        self.authRepository = authRepository
        self.session = session
    }

    /// Validates the form. Returns true when registration may proceed.
    func validate() -> Bool {
        guard !nameText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your name."
            return false
        }
        guard !usernameText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please choose a username."
            return false
        }
        let email = emailText.trimmingCharacters(in: .whitespaces)
        guard email.contains("@"), email.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return false
        }
        guard !phoneText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your phone number."
            return false
        }
        guard !companyText.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Please enter your company name."
            return false
        }
        guard passText.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return false
        }
        guard passText == confirmText else {
            errorMessage = "Passwords do not match."
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
            return "An account with this email or username already exists."
        }
        return LoginPresenter.message(for: error)
    }
}
