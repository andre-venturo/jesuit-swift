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

    var body: some View {
        TabView(selection: $router.selection) {
            HomeScreen()
                .tabItem { Label("Home", systemImage: "house.fill") }
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

            MoreScreen()
                .tabItem { Label("More", systemImage: "ellipsis") }
                .tag(MainTab.more)
        }
        .tint(.accent)
        .toolbar(.hidden, for: .navigationBar)
        .hotReloadable()
    }
}
