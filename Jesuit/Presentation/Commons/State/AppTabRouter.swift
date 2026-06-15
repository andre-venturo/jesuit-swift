//
//  AppTabRouter.swift
//  Jesuit
//
//  Shared selection for the root tab bar, so screens (e.g. the dashboard's
//  Quick Create tiles) can switch tabs.
//

import Observation

/// The root tabs shown after login.
enum MainTab: Hashable, Sendable {
    case home, kontak, penerimaan, pengeluaran, more
}

@Observable
@MainActor
final class AppTabRouter {
    var selection: MainTab = .home

    func select(_ tab: MainTab) {
        selection = tab
    }
}
