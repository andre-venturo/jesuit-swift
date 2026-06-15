//
//  AppStrings.swift
//  Jesuit
//
//  Centralised user-facing copy and storage keys, mirroring the draft-core-v1
//  skeleton. Referenced by `AppError` and `Validators`.
//

/// All localizable strings in one place.
///
/// `nonisolated` so the constants are reachable from any isolation domain
/// (the module defaults to `MainActor` isolation under Swift 6).
nonisolated enum AppStrings {

    // MARK: - App
    static let appName    = "Jesuit"
    static let appVersion = "1.0.0"

    // MARK: - Auth
    static let login           = "Masuk"
    static let register        = "Daftar"
    static let logout          = "Keluar"
    static let email           = "Email"
    static let password        = "Kata Sandi"
    static let confirmPassword  = "Konfirmasi Kata Sandi"
    static let fullName        = "Nama Lengkap"
    static let forgotPassword  = "Lupa Kata Sandi?"

    // MARK: - Validation
    static let fieldRequired       = "Kolom ini wajib diisi"
    static let invalidEmail        = "Masukkan alamat email yang valid"
    static let passwordTooShort    = "Kata sandi minimal 8 karakter"
    static let passwordsDoNotMatch = "Kata sandi tidak cocok"

    // MARK: - Errors
    static let errorGeneric      = "Terjadi kesalahan. Silakan coba lagi."
    static let errorNetwork      = "Tidak ada koneksi internet."
    static let errorUnauthorized = "Sesi berakhir. Silakan masuk kembali."
    static let errorNotFound     = "Sumber daya tidak ditemukan."
    static let errorServerError  = "Kesalahan server. Silakan coba nanti."

    // MARK: - Storage keys (Keychain + UserDefaults)
    enum Keys {
        static let accessToken       = "access_token"
        static let refreshToken      = "refresh_token"
        static let userId            = "user_id"
        static let themeMode         = "theme_mode"
        static let onboardingDone    = "onboarding_done"
        static let pushNotifications = "push_notifications"
    }
}
