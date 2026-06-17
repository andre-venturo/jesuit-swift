//
//  ChangePasswordPresenter.swift
//  Jesuit
//
//  Backs the "Ubah Password" sheet: validates the form and calls
//  `PUT /users/me/password`.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class ChangePasswordPresenter {
    private let authRepository: AuthRepositoryProtocol

    init(authRepository: AuthRepositoryProtocol) {
        self.authRepository = authRepository
    }

    var currentPassword = ""
    var newPassword = ""
    var confirmPassword = ""

    private(set) var isSaving = false
    var errorMessage: String?

    /// Minimum length the backend enforces for a new password.
    private let minLength = 6

    var isValid: Bool {
        !currentPassword.isEmpty
            && newPassword.count >= minLength
            && newPassword == confirmPassword
    }

    /// Inline hint when the form can't be submitted yet (nil while still empty).
    var validationHint: String? {
        if newPassword.isEmpty && confirmPassword.isEmpty { return nil }
        if newPassword.count < minLength {
            return "Kata sandi baru minimal \(minLength) karakter."
        }
        if newPassword != confirmPassword {
            return "Konfirmasi kata sandi tidak cocok."
        }
        return nil
    }

    /// Submits the change. Returns `true` on success so the caller can dismiss.
    func submit() async -> Bool {
        guard isValid, !isSaving else { return false }
        isSaving = true
        errorMessage = nil
        defer { isSaving = false }
        do {
            try await authRepository.changePassword(current: currentPassword, new: newPassword)
            return true
        } catch let error as NetworkError {
            if case let .serverError(_, message?) = error, !message.isEmpty {
                errorMessage = message
            } else if case .unauthorized = error {
                errorMessage = "Kata sandi saat ini salah."
            } else {
                errorMessage = "Gagal mengubah kata sandi."
            }
            return false
        } catch {
            errorMessage = "Gagal mengubah kata sandi."
            return false
        }
    }
}
