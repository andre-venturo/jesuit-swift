//
//  NavigationService.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import Observation
import SwiftUI
import UIPilot

@Observable
final class NavigationService {
    var pilot = UIPilot(initial: AppRoute.login)

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
