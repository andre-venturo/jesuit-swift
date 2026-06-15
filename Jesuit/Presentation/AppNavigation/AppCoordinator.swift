//
//  AppCoordinator.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import SwiftUI
import Swinject
import UIPilot

struct AppCoordinator: View {
    @Injected private var navigation: NavigationService
    @Injected private var authRepository: AuthRepositoryProtocol
    @Injected private var session: AuthSession
    @State private var didLaunch = false

    var body: some View {
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
                default:
                    Text("Why you here?")
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
