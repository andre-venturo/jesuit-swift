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
    @State private var presenter = AppDI.shared.resolver(HomePresenter.self)
    @State private var isLoggingOut = false
    @State private var showEditProfile = false
    @State private var showProfileSaved = false
    @State private var showChangePassword = false
    @State private var showPasswordChanged = false
    @State private var showLaporan = false
    @State private var showTransfer = false
    @State private var showAsset = false
    @State private var showApproval = false
    @State private var approval = AppDI.shared.resolver(ApprovalInboxPresenter.self)

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
                    Button {
                        showEditProfile = true
                    } label: {
                        MoreRow(icon: "person.crop.circle", title: "Ubah Profil", value: "")
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 52)
                    Button {
                        showChangePassword = true
                    } label: {
                        MoreRow(icon: "lock", title: "Ubah Password", value: "")
                    }
                    .buttonStyle(.plain)
                    if session.can(Permission.cashApprove) {
                        Divider().padding(.leading, 52)
                        Button {
                            showApproval = true
                        } label: {
                            MoreRow(icon: "checkmark.seal", title: "Persetujuan", value: "", badge: approval.badgeCount)
                        }
                        .buttonStyle(.plain)
                    }
                    Divider().padding(.leading, 52)
                    Button {
                        showTransfer = true
                    } label: {
                        MoreRow(icon: "arrow.left.arrow.right", title: "Transfer Dana", value: "")
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 52)
                    Button {
                        showAsset = true
                    } label: {
                        MoreRow(icon: "shippingbox", title: "Aset", value: "")
                    }
                    .buttonStyle(.plain)
                    Divider().padding(.leading, 52)
                    Button {
                        showLaporan = true
                    } label: {
                        MoreRow(icon: "chart.bar.doc.horizontal", title: "Laporan", value: "")
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    guard !isLoggingOut else { return }
                    isLoggingOut = true
                    Task {
                        await presenter.logout()
                        isLoggingOut = false
                        navigation.popTo(root: .login)
                    }
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
        .navigationDestination(isPresented: $showTransfer) {
            TransferScreen()
        }
        .navigationDestination(isPresented: $showAsset) {
            AssetScreen()
        }
        .navigationDestination(isPresented: $showApproval) {
            ApprovalInboxScreen()
        }
        .onChange(of: showApproval) { _, shown in
            if !shown { Task { await approval.loadBadge() } }  // refresh badge after the inbox pops
        }
        .task {
            if session.can(Permission.cashApprove) { await approval.loadBadge() }
        }
        .alert("Profil berhasil diperbarui", isPresented: $showProfileSaved) {
            Button("OK", role: .cancel) {}
        }
        .alert("Kata sandi berhasil diubah", isPresented: $showPasswordChanged) {
            Button("OK", role: .cancel) {}
        }
        .hotReloadable()
    }

    private var initials: String {
        presenter.userName.split(separator: " ").prefix(2)
            .compactMap { $0.first }.map(String.init).joined().uppercased()
    }
}

struct MoreRow: View {
    let icon: String
    let title: LocalizedStringKey
    let value: String
    var badge: Int = 0

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .foregroundStyle(.accent)
                .frame(width: 24)
            Text(title)
                .customFont(.medium, Typography.body)
                .foregroundStyle(.title)
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
