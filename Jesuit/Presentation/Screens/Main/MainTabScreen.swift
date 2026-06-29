//
//  MainTabScreen.swift
//  Jesuit
//
//  Root tab bar shown after login: Home, Kontak, Penerimaan,
//  Pengeluaran, More.
//

import SwiftUI

struct MainTabScreen: View {
    @State private var router = AppDI.shared.resolver(AppTabRouter.self)
    @Injected private var session: AuthSession
    @State private var approval = AppDI.shared.resolver(ApprovalInboxPresenter.self)

    var body: some View {
        TabView(selection: $router.selection) {
            NavigationStack { HomeScreen() }
                .tabItem { Label("Beranda", systemImage: "house.fill") }
                .tag(MainTab.home)

            KontakScreen()
                .tabItem { Label("Kontak", systemImage: "person.2.fill") }
                .tag(MainTab.kontak)

            PenerimaanScreen()
                .tabItem { Label("Penerimaan", systemImage: "arrow.down.circle.fill") }
                .tag(MainTab.penerimaan)

            PengeluaranScreen()
                .tabItem { Label("Pengeluaran", systemImage: "arrow.up.circle.fill") }
                .tag(MainTab.pengeluaran)

            NavigationStack { MoreScreen() }
                .tabItem { Label("Lainnya", systemImage: "ellipsis") }
                .tag(MainTab.more)
                .badge(approval.badgeCount)  // 0 hides it automatically
        }
        .tint(.accent)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            if session.can(Permission.cashApprove) { await approval.loadBadge() }
        }
        .hotReloadable()
    }
}
