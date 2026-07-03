//
//  BiometricAuth.swift
//  Jesuit
//
//  Opt-in Face ID / Touch ID lock for the launch auto-restore. Stateless helper
//  around LAContext — biometrics only (no device-passcode fallback), matching the
//  pragmatic `TokenKeychainActor.shared` singleton style. No credentials are stored;
//  this only gates access to the already-persisted session (see AppCoordinator).
//

import LocalAuthentication

enum BiometricAuth {
    private static let enabledKey = "face_id_enabled"   // UserDefaults, same pattern as AppTabRouter

    /// Whether the user has turned the launch lock on in Settings.
    static var isEnabled: Bool {
        get { UserDefaults.standard.bool(forKey: enabledKey) }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    /// True after a *soft* logout: the token pair was deliberately kept in the
    /// Keychain so "Masuk dengan Face ID" can restore the session, but cold launch
    /// must land on the login screen instead of silently auto-restoring. Cleared on
    /// any successful sign-in (see `AuthSession.update`).
    static var didSoftSignOut: Bool {
        get { UserDefaults.standard.bool(forKey: "did_soft_sign_out") }
        set { UserDefaults.standard.set(newValue, forKey: "did_soft_sign_out") }
    }

    /// Device supports biometrics AND the user is enrolled. False on the simulator
    /// until a face is enrolled (Features → Face ID → Enrolled).
    static var canEvaluate: Bool {
        LAContext().canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    /// `.faceID` / `.touchID` / `.none` — drives the toggle & lock-screen copy.
    static var biometryType: LABiometryType {
        let ctx = LAContext()
        _ = ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
        return ctx.biometryType
    }

    /// Human label for the current biometry ("Face ID" / "Touch ID").
    static var label: String {
        switch biometryType {
        case .touchID: return "Touch ID"
        default: return "Face ID"
        }
    }

    /// SF Symbol matching `label`, so views don't need LocalAuthentication.
    static var systemImage: String {
        biometryType == .touchID ? "touchid" : "faceid"
    }

    enum Result {
        case success
        /// Cancelled or wrong face/finger — retryable.
        case failed
        /// Too many failed attempts: iOS locked biometrics device-wide until the
        /// device passcode is entered (e.g. on the lock screen). Not retryable
        /// from inside the app — steer the user to password login.
        case lockout
    }

    /// Prompts biometrics. Never throws; maps LAError to a UI-friendly result.
    static func authenticate(reason: String) async -> Result {
        let ctx = LAContext()
        var error: NSError?
        guard ctx.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            // During a lockout canEvaluatePolicy itself fails with biometryLockout.
            return error?.code == LAError.biometryLockout.rawValue ? .lockout : .failed
        }
        do {
            return try await ctx.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics,
                                                localizedReason: reason) ? .success : .failed
        } catch let laError as LAError where laError.code == .biometryLockout {
            return .lockout
        } catch {
            return .failed
        }
    }

    /// Copy for the lockout state, shared by the lock screen and login.
    static var lockoutMessage: String {
        "\(label) terkunci karena terlalu banyak percobaan gagal. Buka kunci perangkat dengan kode sandi, lalu coba lagi — atau masuk dengan kata sandi."
    }
}
