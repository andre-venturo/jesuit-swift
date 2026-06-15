//
//  SplashScreen.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import SwiftUI

struct SplashScreen: View {
    @State private var isAnimating = false
    private let bounds = UIScreen.main.bounds

    var body: some View {
        Text("Splash Screen")
            .customFont(.semibold, 30)
            .scaleEffect(isAnimating ? 1.3 : 1.0)
            .foregroundStyle(.white)
            .frame(width: screenBounds.width, height: screenBounds.height)
            .background(.accent)
            .animation(.bouncy, value: isAnimating)
            .task {
                isAnimating.toggle()
                try? await Task.sleep(nanoseconds: 500_000_000)
                isAnimating.toggle()
            }
            .hotReloadable()
    }
}

// #Preview {
//    SplashScreen()
//        .inPreviewNavigation()
// }
