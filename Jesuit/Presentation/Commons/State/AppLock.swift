//
//  AppLock.swift
//  Jesuit
//
//  Banking-style auto-lock. When the Face ID lock is armed (toggle on in Settings
//  + biometrics enrolled), the app locks on cold launch, on backgrounding, and after
//  a period of inactivity while foregrounded. Unlock is biometric-only. This is a
//  *soft* lock: the session and Keychain token stay intact, we only gate the UI, so
//  resuming needs no network — unlike the hard "Keluar" logout that revokes the token.
//

import SwiftUI

@Observable
@MainActor
final class AppLock {
    private(set) var isLocked = false

    private let session: AuthSession

    // ponytail: 3-minute idle timeout, a constant not a setting — make it configurable
    // only if someone actually asks.
    private let idleTimeout: TimeInterval = 180
    private var idleTimer: Timer?

    init(session: AuthSession) {
        self.session = session
    }

    /// Locking only engages with an authenticated session, when the user enabled it,
    /// and while the device can still evaluate biometrics. If biometrics get
    /// disabled/unenrolled later this is false and the app simply never locks — no
    /// regression, and no lockout with no way back in. The session check keeps the
    /// login screen from ever getting locked.
    var isArmed: Bool {
        session.isAuthenticated && BiometricAuth.isEnabled && BiometricAuth.canEvaluate
    }

    func lock() {
        guard isArmed, !isLocked else { return }
        clearTimer()
        isLocked = true
    }

    /// Called after a successful biometric unlock.
    func unlocked() {
        isLocked = false
        armIdleTimer()
    }

    /// Hard logout / disable path — drop the lock without biometrics.
    func reset() {
        clearTimer()
        isLocked = false
    }

    /// Any user interaction resets the inactivity countdown.
    func noteActivity() { armIdleTimer() }

    func scenePhaseChanged(to phase: ScenePhase) {
        switch phase {
        case .background:
            lock()                        // leaving the app locks it (banking-style)
        case .active:
            if !isLocked { armIdleTimer() }
        default:
            break                         // ignore .inactive (transient: auth sheet, control center)
        }
    }

    private func armIdleTimer() {
        guard isArmed, !isLocked else { return }
        clearTimer()
        idleTimer = Timer.scheduledTimer(withTimeInterval: idleTimeout, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.lock() }
        }
    }

    private func clearTimer() {
        idleTimer?.invalidate()
        idleTimer = nil
    }
}
