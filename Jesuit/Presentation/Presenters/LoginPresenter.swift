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
    /// True when "Masuk dengan Face ID" should show: the feature is on, biometrics
    /// are enrolled, and a kept token pair exists (soft sign-out keeps it).
    private(set) var canBiometricLogin = false

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

    /// Refreshes `canBiometricLogin` (async — keychain read goes through the actor).
    func checkBiometricLogin() async {
        guard BiometricAuth.isEnabled, BiometricAuth.canEvaluate else {
            canBiometricLogin = false
            return
        }
        let tokens = (try? await TokenKeychainActor.shared.getTokens()) ?? nil
        canBiometricLogin = tokens != nil
    }

    /// Face-ID sign-in: biometric gate + restore of the kept session. No password
    /// is stored anywhere — this reuses the token pair a soft sign-out left behind.
    func biometricLogin() async -> Bool {
        switch await BiometricAuth.authenticate(reason: "Masuk dengan \(BiometricAuth.label)") {
        case .success:
            break
        case .lockout:
            // Too many failed scans: iOS blocks biometrics until the device passcode
            // clears it. Tell the user instead of failing silently.
            errorMessage = BiometricAuth.lockoutMessage
            await checkBiometricLogin()   // canEvaluate is false now — hides the button
            return false
        case .failed:
            return false   // cancelled/wrong face: stay on login, no error banner
        }
        isLoading = true
        defer { isLoading = false }

        if let me = await authRepository.restoreSession() {
            session.update(with: me)
            return true
        }
        // Token expired or was revoked; the failed restore cleared the keychain.
        errorMessage = "Sesi berakhir. Masuk dengan kata sandi."
        await checkBiometricLogin()
        return false
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
