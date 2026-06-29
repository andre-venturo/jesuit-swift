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
            // Rendered from the user's persisted order (More pinned last). `id: \.self`
            // keeps each tab's NavigationStack identity stable across reorders.
            ForEach(router.tabs, id: \.self) { tab in
                NavigationStack { destination(tab) }
                    .tabItem { Label(tab.title, systemImage: tab.systemImage) }
                    .tag(tab)
                    .badge(tab == .more ? approval.badgeCount : 0)  // 0 hides it automatically
            }
        }
        .tint(.accent)
        .toolbar(.hidden, for: .navigationBar)
        // The "Atur Navigasi" editor is NOT presented here. It is pushed as a top-level
        // UIPilot route (AppRoute.editNavigation) from MoreScreen, so at the UIKit level
        // it lands on UIPilot's UINavigationController as a sibling of this whole
        // TabView host — fully occluding the UITabBarController while a reorder rebuilds
        // it (no blink) and getting a native back chevron + swipe-back for free.
        .task {
            if session.can(Permission.cashApprove) { await approval.loadBadge() }
        }
        .hotReloadable()
    }

    @ViewBuilder
    private func destination(_ tab: MainTab) -> some View {
        switch tab {
        case .home: HomeScreen()
        case .kontak: KontakScreen()
        case .penerimaan: PenerimaanScreen()
        case .pengeluaran: PengeluaranScreen()
        case .more: MoreScreen()
        }
    }
}
