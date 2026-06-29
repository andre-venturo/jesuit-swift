//
//  EditNavigationScreen.swift
//  Jesuit
//
//  "Atur Navigasi" — drag-to-reorder editor for the bottom tab bar. Pushed as a
//  top-level UIPilot route (AppRoute.editNavigation), so at the UIKit level it lands on
//  UIPilot's UINavigationController as a sibling of the MainTabScreen host — fully
//  occluding the TabView / UITabBarController while a reorder rebuilds it (no tab-bar
//  blink on close). UIPilot keeps its own bar hidden, so this screen wraps its content
//  in its OWN NavigationStack to get the standard app nav bar (inline title + leading
//  back chevron → navigation.pop()), matching the rest of the app's pushed pages. Drags
//  mutate a LOCAL copy and commit to the router live. "Lainnya" is pinned last.
//

import SwiftUI

struct EditNavigationScreen: View {
    @Injected private var navigation: NavigationService
    @Injected private var session: AuthSession
    @State private var router = AppDI.shared.resolver(AppTabRouter.self)
    /// Working copy edited while dragging; committed to `router` as moves happen
    /// (the pushed editor occludes the TabView, so the rebuild is never visible).
    @State private var localOrder: [MainTab] = []
    /// Working copy for the "Lainnya" menu rows (permission-filtered).
    @State private var localMenuOrder: [MoreMenuItem] = []

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(localOrder, id: \.self) { tab in
                        tabRow(tab)
                    }
                    .onMove { from, to in
                        localOrder.move(fromOffsets: from, toOffset: to)
                        // Commit now; this editor is pushed over the TabView, so the
                        // resulting UITabBarController rebuild happens behind the opaque
                        // pushed VC and is never visible. Animations off = instant swap.
                        var t = Transaction()
                        t.disablesAnimations = true
                        withTransaction(t) { router.applyOrder(localOrder) }
                    }
                } header: {
                    sectionHeader("Tab")
                } footer: {
                    Text("Seret untuk mengubah urutan tab di bilah bawah.")
                        .customFont(.regular, Typography.caption2)
                        .foregroundStyle(.subtitle)
                }

                Section {
                    tabRow(.more)
                        .moveDisabled(true)
                } footer: {
                    Text("Selalu di posisi terakhir.")
                        .customFont(.regular, Typography.caption2)
                        .foregroundStyle(.subtitle)
                }

                Section {
                    ForEach(localMenuOrder, id: \.self) { item in
                        menuRow(item)
                    }
                    .onMove { from, to in
                        localMenuOrder.move(fromOffsets: from, toOffset: to)
                        router.applyMenuOrder(localMenuOrder)
                    }
                } header: {
                    sectionHeader("Menu Lainnya")
                } footer: {
                    Text("Seret untuk mengubah urutan menu di Lainnya.")
                        .customFont(.regular, Typography.caption2)
                        .foregroundStyle(.subtitle)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .environment(\.editMode, .constant(.active))
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Atur Navigasi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { navigation.pop() } label: {
                        // White chevron (no accent tint) to match the app's native
                        // back button on pushed pages like "Ubah Kontak".
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.title)
                    }
                }
            }
            .onAppear {
                if localOrder.isEmpty { localOrder = router.order }
                if localMenuOrder.isEmpty {
                    localMenuOrder = router.menuOrder.filter { $0.isVisible(session) }
                }
            }
        }
        .hotReloadable()
    }

    private func tabRow(_ tab: MainTab) -> some View {
        HStack(spacing: 16) {
            Image(systemName: tab.systemImage)
                .foregroundStyle(.accent)
                .frame(width: 24)
            Text(tab.title)
                .customFont(.medium, Typography.body)
                .foregroundStyle(.title)
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.textFieldBG)
    }

    private func menuRow(_ item: MoreMenuItem) -> some View {
        HStack(spacing: 16) {
            Image(systemName: item.systemImage)
                .foregroundStyle(.accent)
                .frame(width: 24)
            Text(item.title)
                .customFont(.medium, Typography.body)
                .foregroundStyle(.title)
            Spacer()
        }
        .padding(.vertical, 4)
        .listRowBackground(Color.textFieldBG)
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .customFont(.medium, Typography.caption2)
            .foregroundStyle(.subtitle)
    }
}
