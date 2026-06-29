//
//  NavigationService.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import Observation
import SwiftUI

@Observable
final class NavigationService {
    var pilot = UIPilot(initial: AppRoute.login)

    init() {
        // The home route sits on top of login in the stack, so a raw edge-swipe-back
        // would pop to login. Block it there — HomeScreen turns that swipe into an
        // "exit app?" prompt instead. Every other route keeps native swipe-back.
        pilot.interactivePopGate = { [weak pilot] in pilot?.routes.last != .home }
    }

    // Navigate to route
    func navigate(to route: AppRoute) {
        pilot.push(route)
    }

    // Go back
    func pop() {
        pilot.pop()
    }

    // Replace current screen
    func replace(with route: AppRoute) {
        pilot.pop()
        pilot.push(route)
    }

    // Pop to root
    func popTo(root: AppRoute) {
        pilot.popTo(root)
    }
}
