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
    @State private var didLaunch = false

    var body: some View {
        content.dismissKeyboardOnTap()
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
    /// returning user with valid credentials skips the login screen.
    @MainActor
    private func launch() async {
        async let minimumSplash: Void = Task.sleep(nanoseconds: 1_000_000_000)

        if let me = await authRepository.restoreSession() {
            session.update(with: me)
            // Mirror the login flow's `navigate(to: .home)` so the stack shape
            // matches an interactive sign-in.
            navigation.navigate(to: .home)
        }

        try? await minimumSplash
        didLaunch = true
    }
}
