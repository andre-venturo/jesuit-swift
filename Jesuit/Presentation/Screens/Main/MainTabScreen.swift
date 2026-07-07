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
    /// True once the first `.task` ran. `.task` re-fires every time a top-level
    /// UIPilot route (Persetujuan/Transfer/Aset/Atur Navigasi) pops back and this
    /// view's hosting VC reappears — without the guard that yanked the user to Home.
    @State private var didResetToHome = false

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
            // AppTabRouter is a singleton, so the last-selected tab survives a
            // logout/login in the same process — a fresh tab bar (new sign-in or
            // session restore) should always open on Home. Only on the FIRST
            // appearance though: login rebuilds this view (fresh @State), while a
            // pop-back from a UIPilot route must keep the current tab.
            if !didResetToHome {
                didResetToHome = true
                router.select(.home)
            }
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
