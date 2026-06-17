//
//  LoginPresenter.swift
//  Jesuit
//
//  Created by admin on 25/11/25.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class LoginPresenter {
    var emailText: String = ""
    var passText: String = ""
    var errorMessage: String?
    var isLoading: Bool = false

    private let authRepository: AuthRepositoryProtocol
    private let session: AuthSession

    init(authRepository: AuthRepositoryProtocol, session: AuthSession) {
        self.authRepository = authRepository
        self.session = session
    }

    /// Validates the form. `login` may be an email or a username.
    func validate() -> Bool {
        let login = emailText.trimmingCharacters(in: .whitespaces)
        guard !login.isEmpty else {
            errorMessage = "Masukkan email atau username Anda."
            return false
        }
        guard passText.count >= 6 else {
            errorMessage = "Kata sandi minimal 6 karakter."
            return false
        }
        errorMessage = nil
        return true
    }

    /// Signs in against the backend. Returns true on success so the view can navigate.
    func login() async -> Bool {
        guard validate() else { return false }
        isLoading = true
        defer { isLoading = false }

        do {
            let me = try await authRepository.signIn(
                login: emailText.trimmingCharacters(in: .whitespaces),
                password: passText
            )
            session.update(with: me)
            return true
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
    }

    static func message(for error: Error) -> String {
        if let networkError = error as? NetworkError {
            switch networkError {
            case .unauthorized:
                return "Email/username atau kata sandi salah."
            case .serverError(_, let message):
                return message ?? networkError.localizedDescription
            default:
                return networkError.localizedDescription
            }
        }
        return error.localizedDescription
    }
}
