//
//  AppTabRouter.swift
//  Jesuit
//
//  Shared selection for the root tab bar, so screens (e.g. the dashboard's
//  Quick Create tiles) can switch tabs. Also owns the user's reorderable tab
//  order (persisted in UserDefaults; "Lainnya"/more is always pinned last).
//

import Foundation
import Observation

/// The root tabs shown after login. String-backed so the chosen order persists.
enum MainTab: String, Hashable, Sendable, CaseIterable {
    case home, kontak, penerimaan, pengeluaran, more

    var title: String {
        switch self {
        case .home: "Beranda"
        case .kontak: "Kontak"
        case .penerimaan: "Penerimaan"
        case .pengeluaran: "Pengeluaran"
        case .more: "Lainnya"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house.fill"
        case .kontak: "person.2.fill"
        case .penerimaan: "arrow.down.circle.fill"
        case .pengeluaran: "arrow.up.circle.fill"
        case .more: "ellipsis"
        }
    }

    /// The tabs users may reorder — everything except the pinned "more" tab.
    static let reorderable: [MainTab] = [.home, .kontak, .penerimaan, .pengeluaran]
}

/// A row in the "Lainnya" (More) tab. String-backed so the chosen order persists.
/// `allCases` order is the default (the original hardcoded order).
enum MoreMenuItem: String, Hashable, Sendable, CaseIterable {
    case ubahProfil, ubahPassword, persetujuan, transferDana, aset, laporan, aturNavigasi

    var title: String {
        switch self {
        case .ubahProfil: "Ubah Profil"
        case .ubahPassword: "Ubah Password"
        case .persetujuan: "Persetujuan"
        case .transferDana: "Transfer Dana"
        case .aset: "Aset"
        case .laporan: "Laporan"
        case .aturNavigasi: "Atur Navigasi"
        }
    }

    var systemImage: String {
        switch self {
        case .ubahProfil: "person.crop.circle"
        case .ubahPassword: "lock"
        case .persetujuan: "checkmark.seal"
        case .transferDana: "arrow.left.arrow.right"
        case .aset: "shippingbox"
        case .laporan: "chart.bar.doc.horizontal"
        case .aturNavigasi: "arrow.up.arrow.down"
        }
    }

    /// Only Persetujuan is permission-gated; every other row is always shown.
    func isVisible(_ session: AuthSession) -> Bool {
        self == .persetujuan ? session.can(Permission.cashApprove) : true
    }

    /// The "Lainnya" menu is rendered as one card per section (in `Section.allCases`
    /// order); the user-chosen `menuOrder` still decides row order *within* a section.
    enum Section: String, CaseIterable {
        case pengaturan = "Pengaturan", fitur = "Fitur"
    }

    var section: Section {
        switch self {
        case .persetujuan, .transferDana, .aset, .laporan: .fitur
        case .ubahProfil, .ubahPassword, .aturNavigasi: .pengaturan
        }
    }

    /// Rows the user may reorder. "Atur Navigasi" is excluded — it's pinned in its
    /// own prominent card (you don't reorder the reorder button).
    static let reorderable: [MoreMenuItem] = allCases.filter { $0 != .aturNavigasi }
}

@Observable
@MainActor
final class AppTabRouter {
    var selection: MainTab = .home

    // The "Atur Navigasi" editor is no longer driven by a flag here. It is pushed as a
    // top-level UIPilot route (AppRoute.editNavigation) from MoreScreen, so at the UIKit
    // level it lands on UIPilot's UINavigationController as a sibling of the whole
    // TabView host. That sibling VC fully occludes the UITabBarController while a reorder
    // rebuilds it (no tab-bar blink on close) and gets a native back chevron for free —
    // whereas a push inside a tab made the editor a descendant of the reordered TabView,
    // which blinked the tab bar on close.

    /// The reorderable tabs in user-chosen order (persisted). Excludes `.more`.
    private(set) var order: [MainTab]

    /// What `MainTabScreen` renders, left to right — More is always pinned last.
    var tabs: [MainTab] { order + [.more] }

    /// The "Lainnya" menu rows in user-chosen order (persisted).
    private(set) var menuOrder: [MoreMenuItem]

    private let orderKey = "main_tab_order"
    private let menuOrderKey = "more_menu_order"

    init() {
        order = Self.loadOrder(key: orderKey)
        menuOrder = Self.loadMenuOrder(key: menuOrderKey)
    }

    func select(_ tab: MainTab) {
        selection = tab
    }

    /// Commit a reordered list from the editor in one shot, persisting only if it
    /// actually changed (a no-op avoids needlessly rebuilding the live TabView).
    func applyOrder(_ newOrder: [MainTab]) {
        var sanitized = newOrder.filter { $0 != .more }
        for tab in MainTab.reorderable where !sanitized.contains(tab) { sanitized.append(tab) }
        guard sanitized != order else { return }
        order = sanitized
        UserDefaults.standard.set(order.map(\.rawValue), forKey: orderKey)
    }

    /// Loads the saved order, sanitized: drops unknown/`.more` entries and appends
    /// any reorderable tab missing from the saved list (so a newly added tab still
    /// appears). Falls back to the default order when nothing is stored.
    private static func loadOrder(key: String) -> [MainTab] {
        let saved = (UserDefaults.standard.array(forKey: key) as? [String] ?? [])
            .compactMap(MainTab.init(rawValue:))
            .filter { $0 != .more }
        var result = saved
        for tab in MainTab.reorderable where !result.contains(tab) {
            result.append(tab)
        }
        return result.isEmpty ? MainTab.reorderable : result
    }

    /// Commit a reordered list of "Lainnya" rows. Appends any missing case (e.g. a
    /// permission-gated row the editor never showed, or a future new row) so nothing
    /// is lost — it lands last in storage, where a hidden row stays invisible.
    func applyMenuOrder(_ newOrder: [MoreMenuItem]) {
        var sanitized = newOrder.filter { MoreMenuItem.reorderable.contains($0) }
        for item in MoreMenuItem.reorderable where !sanitized.contains(item) { sanitized.append(item) }
        guard sanitized != menuOrder else { return }
        menuOrder = sanitized
        UserDefaults.standard.set(menuOrder.map(\.rawValue), forKey: menuOrderKey)
    }

    /// Loads the saved "Lainnya" order, sanitized like `loadOrder`: drops unknown/
    /// non-reorderable entries and appends any missing reorderable case. Falls back to
    /// the default order when empty.
    private static func loadMenuOrder(key: String) -> [MoreMenuItem] {
        var result = (UserDefaults.standard.array(forKey: key) as? [String] ?? [])
            .compactMap(MoreMenuItem.init(rawValue:))
            .filter { MoreMenuItem.reorderable.contains($0) }
        for item in MoreMenuItem.reorderable where !result.contains(item) { result.append(item) }
        return result.isEmpty ? MoreMenuItem.reorderable : result
    }
}
