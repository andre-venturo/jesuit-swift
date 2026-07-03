//
//  MoreScreen.swift
//  Jesuit
//
//  More tab: profile summary, settings entries, logout.
//

import SwiftUI

struct MoreScreen: View {
    @Injected private var navigation: NavigationService
    @Injected private var session: AuthSession
    @State private var tabRouter = AppDI.shared.resolver(AppTabRouter.self)
    @State private var presenter = AppDI.shared.resolver(HomePresenter.self)
    @State private var isLoggingOut = false
    @State private var showLogoutConfirm = false
    @State private var showEditProfile = false
    @State private var showProfileSaved = false
    @State private var showChangePassword = false
    @State private var showPasswordChanged = false
    @State private var showLaporan = false
    @State private var approval = AppDI.shared.resolver(ApprovalInboxPresenter.self)
    @State private var faceIDEnabled = BiometricAuth.isEnabled

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                CardContainer {
                    HStack(spacing: 16) {
                        Circle()
                            .fill(Color.accentColor.opacity(0.15))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Text(initials)
                                    .customFont(.bold, Typography.title2)
                                    .foregroundStyle(.accent)
                            )
                        VStack(alignment: .leading, spacing: 3) {
                            Text(presenter.userName)
                                .customFont(.semibold, Typography.headline)
                                .foregroundStyle(.title)
                            Text(presenter.organization)
                                .customFont(.regular, Typography.callout)
                                .foregroundStyle(.subtitle)
                        }
                        Spacer()
                    }
                }

                ListCard {
                    // Rows render in the user-chosen order (edited in "Atur Navigasi"),
                    // filtered by permission. Dividers go between rows, not after the last.
                    let items = tabRouter.menuOrder.filter { $0.isVisible(session) }
                    ForEach(Array(items.enumerated()), id: \.element) { index, item in
                        Button {
                            handle(item)
                        } label: {
                            MoreRow(
                                icon: item.systemImage,
                                title: item.title,
                                value: "",
                                badge: item == .persetujuan ? approval.badgeCount : 0
                            )
                        }
                        .buttonStyle(.plain)
                        if index < items.count - 1 {
                            Divider().padding(.leading, 52)
                        }
                    }
                }

                // Face ID launch lock — only shown when the device supports & is
                // enrolled in biometrics. Enabling confirms the owner can pass it.
                if BiometricAuth.canEvaluate {
                    FormCard("Keamanan") {
                        FormToggleRow(
                            label: "Gunakan \(BiometricAuth.label)",
                            isOn: $faceIDEnabled
                        )
                    }
                }

                // "Atur Navigasi" sits in its own card, styled prominently — it's the
                // entry point to customize the tabs and this menu's order.
                ListCard {
                    Button {
                        handle(.aturNavigasi)
                    } label: {
                        MoreRow(
                            icon: MoreMenuItem.aturNavigasi.systemImage,
                            title: MoreMenuItem.aturNavigasi.title,
                            value: "",
                            prominent: true
                        )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    guard !isLoggingOut else { return }
                    showLogoutConfirm = true
                } label: {
                    Group {
                        if isLoggingOut {
                            ProgressView().tint(.expense)
                        } else {
                            Text("Keluar")
                                .customFont(.semibold, Typography.headline)
                                .foregroundStyle(.expense)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 15)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .disabled(isLoggingOut)
            }
            .padding(16)
        }
        .background(Color.background1.ignoresSafeArea())
        .navigationTitle("Lainnya")
        .exitAppOnLeftEdgeSwipe()
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showEditProfile) {
            EditProfileSheet(onSuccess: { showProfileSaved = true })
        }
        .sheet(isPresented: $showChangePassword) {
            ChangePasswordSheet(onSuccess: { showPasswordChanged = true })
        }
        .sheet(isPresented: $showLaporan) {
            LaporanScreen()
        }
        .task {
            if session.can(Permission.cashApprove) { await approval.loadBadge() }
        }
        .onChange(of: faceIDEnabled) { _, on in
            if on {
                // Confirm the owner can pass biometrics before relying on it at launch.
                Task {
                    if await BiometricAuth.authenticate(reason: "Aktifkan \(BiometricAuth.label)") == .success {
                        BiometricAuth.isEnabled = true
                    } else {
                        faceIDEnabled = false   // revert on cancel/failure/lockout
                    }
                }
            } else {
                BiometricAuth.isEnabled = false
            }
        }
        .alert("Profil berhasil diperbarui", isPresented: $showProfileSaved) {
            Button("OK", role: .cancel) {}
        }
        .alert("Kata sandi berhasil diubah", isPresented: $showPasswordChanged) {
            Button("OK", role: .cancel) {}
        }
        // .alert, not .confirmationDialog — iOS 26 renders dialogs as a popover
        // anchored to the button (tooltip-ish); an alert stays a centered modal.
        .alert("Keluar dari akun?", isPresented: $showLogoutConfirm) {
            Button("Batal", role: .cancel) {}
            Button("Keluar", role: .destructive) {
                isLoggingOut = true
                Task {
                    await presenter.logout()
                    isLoggingOut = false
                    navigation.popTo(root: .login)
                }
            }
        } message: {
            Text(BiometricAuth.isEnabled && BiometricAuth.canEvaluate
                 ? "Anda dapat masuk kembali dengan \(BiometricAuth.label)."
                 : "Anda harus masuk kembali dengan kata sandi.")
        }
        .hotReloadable()
    }

    private func handle(_ item: MoreMenuItem) {
        switch item {
        case .ubahProfil: showEditProfile = true
        case .ubahPassword: showChangePassword = true
        case .laporan: showLaporan = true
        case .persetujuan: navigation.navigate(to: .approval)
        case .transferDana: navigation.navigate(to: .transfer)
        case .aset: navigation.navigate(to: .asset)
        // Pushed as a top-level UIPilot route, NOT inside this tab's NavigationStack, so
        // the editor occludes the TabView while the reorder rebuilds the UITabBarController
        // (no tab-bar blink on close) with a native back chevron + swipe-back.
        case .aturNavigasi: navigation.navigate(to: .editNavigation)
        }
    }

    private var initials: String {
        presenter.userName.split(separator: " ").prefix(2)
            .compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

struct MoreRow: View {
    let icon: String
    let title: String
    let value: String
    var badge: Int = 0
    /// Accent-tinted, semibold styling to make a row stand out (e.g. "Atur Navigasi").
    var prominent: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(.accent)
                .frame(width: 24)
            Text(title)
                .customFont(prominent ? .semibold : .medium, Typography.body)
                .foregroundStyle(prominent ? Color.accentColor : .title)
            Spacer()
            if badge > 0 {
                Text("\(badge)")
                    .customFont(.semibold, Typography.caption2)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(ReceiptStatus.pendingApproval.tint))
            }
            if !value.isEmpty {
                Text(value)
                    .customFont(.regular, Typography.callout)
                    .foregroundStyle(.subtitle)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(.subtitle)
        }
        .padding(16)
        .contentShape(Rectangle())
    }
}
