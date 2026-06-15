//
//  JesuitApp.swift
//  Jesuit
//
//  Created by admin on 18/11/25.
//

import SwiftUI

@main
struct JesuitApp: App {
    init() {
        _ = AppDI.shared
    }

    var body: some Scene {
        WindowGroup {
            AppCoordinator()
                .preferredColorScheme(.dark)
        }
    }
}
