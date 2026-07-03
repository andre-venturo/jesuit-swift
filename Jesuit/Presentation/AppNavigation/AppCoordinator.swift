//
//  AppCoordinator.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import SwiftUI
import Swinject

struct AppCoordinator: View {
    @Injected private var navigation: NavigationService
    @Injected private var authRepository: AuthRepositoryProtocol
    @Injected private var session: AuthSession
    @Injected private var appLock: AppLock
    @Environment(\.scenePhase) private var scenePhase
    @State private var didLaunch = false

    var body: some View {
        ZStack {
            content

            // Banking-style lock overlay, shown whenever AppLock is engaged — cold
            // launch, return from background, or idle timeout.
            // ponytail: this gates the live UI, not the app-switcher snapshot. Add a
            // resign-active privacy blur if hiding the backgrounded snapshot matters.
            if didLaunch && appLock.isLocked {
                BiometricLockView(
                    onUnlocked: { appLock.unlocked() },
                    onUsePassword: { logoutFromLock() }
                )
                .transition(.opacity)
            }
        }
        .background(ActivityDetector { appLock.noteActivity() })
        .onChange(of: scenePhase) { _, phase in appLock.scenePhaseChanged(to: phase) }
        .dismissKeyboardOnTap()
    }

    @ViewBuilder
    private var content: some View {
        if !didLaunch {
            SplashScreen()
                .task { await launch() }
        } else {
            UIPilotHost(navigation.pilot) { route in
                switch route {
                case .login:
                    LoginScreen()
                case .home:
                    MainTabScreen()
                case .register:
                    RegisterScreen()
                case .forgotPassword:
                    ForgotPasswordScreen()
                case .resetPassword:
                    ResetPasswordScreen()
                case .editNavigation:
                    // Pushed onto UIPilot's UIKit UINavigationController as a sibling of
                    // the MainTabScreen host. The pushed VC fully occludes the TabView /
                    // UITabBarController while a reorder rebuilds it, so there is no
                    // tab-bar blink on close, and UIKit gives a native back chevron +
                    // swipe-back for free. Rendered BARE (no NavigationStack wrapper) —
                    // wrapping it would create a duplicate/nested nav bar over UIPilot's.
                    EditNavigationScreen()
                case .transfer:
                    // Pushed as a top-level UIPilot route (sibling of MainTabScreen) so
                    // the pushed VC occludes the TabView and the tab bar doesn't blink on
                    // pop — same reason as .editNavigation. (A push inside the tab's own
                    // NavigationStack blinked the tab bar restoring on close.)
                    TransferScreen()
                case .asset:
                    AssetScreen()
                case .approval:
                    ApprovalInboxScreen()
                case .organizationSwitcher:
                    OrganizationSwitcherSheet()
                default:
                    Text("Halaman tidak ditemukan.")
                }
            }
            .ignoresSafeArea(.all)
        }
    }

    /// Restores a stored session (if any) before revealing the UI, so a
    /// returning user with valid credentials skips the login screen. When the
    /// Face ID lock is armed, the session is restored but immediately locked so
    /// the biometric overlay gates access on cold launch.
    @MainActor
    private func launch() async {
        async let minimumSplash: Void = Task.sleep(nanoseconds: 1_000_000_000)

        // After a *soft* sign-out the tokens were kept for "Masuk dengan Face ID",
        // but the user chose to log out — land on the login screen, don't restore.
        if BiometricAuth.didSoftSignOut {
            // fall through to the login root
        } else if let me = await authRepository.restoreSession() {
            session.update(with: me)
            // Mirror the login flow's `navigate(to: .home)` so the stack shape
            // matches an interactive sign-in.
            navigation.navigate(to: .home)
            appLock.lock()   // no-op unless armed; covers home until biometrics pass
        }

        try? await minimumSplash
        didLaunch = true
    }

    /// Lock-screen escape back to the login screen. Soft sign-out (tokens kept) so
    /// the user can still enter with Face ID or a fresh password — mirrors
    /// `HomePresenter.logout()`.
    @MainActor
    private func logoutFromLock() {
        Task {
            if BiometricAuth.isEnabled && BiometricAuth.canEvaluate {
                BiometricAuth.didSoftSignOut = true
            } else {
                try? await authRepository.logout()
            }
            session.clear()
            appLock.reset()
            navigation.popTo(root: .login)
        }
    }
}
