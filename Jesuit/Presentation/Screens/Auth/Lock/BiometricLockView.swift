//
//  BiometricLockView.swift
//  Jesuit
//
//  Shown when the app is locked (cold launch / background / idle) with the Face ID
//  lock armed. Auto-fires the biometric prompt once; on failure the user retries or
//  drops to the password login. A biometry lockout (too many failed attempts) is
//  surfaced explicitly — retrying is pointless until the device passcode clears it.
//

import SwiftUI

struct BiometricLockView: View {
    /// Called after a successful scan; the coordinator reveals the app.
    let onUnlocked: () -> Void
    /// Abandons the locked session and shows the password login instead.
    let onUsePassword: () -> Void

    @State private var isAuthenticating = false
    @State private var isLockedOut = false

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(.imageLogin)
                .resizable()
                .scaledToFit()
                .frame(width: 60)

            Text("Jesuit terkunci")
                .customFont(.bold, Typography.title)
                .foregroundStyle(.title)

            Text(isLockedOut
                 ? BiometricAuth.lockoutMessage
                 : "Buka dengan \(BiometricAuth.label) untuk melanjutkan")
                .customFont(.medium, Typography.body)
                .foregroundStyle(isLockedOut ? .expense : .subtitle)
                .multilineTextAlignment(.center)

            Spacer()

            // Retrying during a lockout can't even show the system prompt — hide the
            // scan button and leave only the password escape.
            if !isLockedOut {
                Button(action: { Task { await unlock() } }) {
                    Group {
                        if isAuthenticating {
                            ProgressView().tint(.white)
                        } else {
                            Text("Buka dengan \(BiometricAuth.label)")
                                .customFont(.medium, Typography.title2)
                                .foregroundStyle(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(.accent)
                    .cornerRadius(12)
                }
                .disabled(isAuthenticating)
            }

            Button("Masuk dengan kata sandi", action: onUsePassword)
                .font(.customFont(.medium, Typography.body))
                .foregroundStyle(isLockedOut ? .accent : .mySecondary)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.background1.ignoresSafeArea())
        .task { await unlock() }   // auto-prompt on appear
        .hotReloadable()
    }

    private func unlock() async {
        guard !isAuthenticating else { return }
        isAuthenticating = true
        defer { isAuthenticating = false }

        switch await BiometricAuth.authenticate(reason: "Buka Jesuit dengan \(BiometricAuth.label)") {
        case .success:
            onUnlocked()
        case .lockout:
            isLockedOut = true
        case .failed:
            break   // cancelled/wrong face: stay, user retries or uses password
        }
    }
}
