//
//  SplashScreen.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//
//  Brand splash: the SERIKAT JESUS logo on a clean light field, with a gentle
//  fade-in + settle animation. Shown by `AppCoordinator` while the stored
//  session is restored (it enforces the minimum on-screen time).
//

import SwiftUI

struct SplashScreen: View {
    @State private var appeared = false

    var body: some View {
        ZStack {
            // Soft brand-tinted backdrop so the navy/orange mark reads cleanly
            // in both light and dark appearance.
            LinearGradient(
                colors: [Color.white, Color(hex: "F4F5FB")],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("LogoSerikatJesus")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: screenBounds.width * 0.68)
                    .opacity(appeared ? 1 : 0)
                    .scaleEffect(appeared ? 1 : 0.92)
                    .animation(.spring(response: 0.7, dampingFraction: 0.7), value: appeared)

                ProgressView()
                    .tint(AppTheme.accent)
                    .opacity(appeared ? 1 : 0)
                    .animation(.easeIn(duration: 0.4).delay(0.35), value: appeared)
            }
        }
        .frame(width: screenBounds.width, height: screenBounds.height)
        .task { appeared = true }
        .hotReloadable()
    }
}

#Preview {
    SplashScreen()
}
