//
//  HotReload.swift
//  Jesuit
//
//  Hot reloading support via Inject (https://github.com/krzysztofzablocki/Inject).
//
//  Apply `.hotReloadable()` to a view's body. In DEBUG builds it observes the
//  InjectionIII / HotReloading daemon and live-swaps the view when its source
//  file is saved; in release builds it compiles to a no-op.
//
//  Requirements to actually see reloads at runtime:
//    1. Install the InjectionIII app (Mac App Store) or run the HotReloading
//       daemon, and point it at this project directory.
//    2. Run the app on the Simulator from Xcode (Cmd+R). The `-interposable`
//       linker flag is already set on the Debug build.
//    3. Edit a `.hotReloadable()` view's body and save — it updates live.
//

import SwiftUI
import Inject

extension View {
    /// Enables Inject-based hot reloading for this view in DEBUG builds.
    /// No-op in release builds.
    func hotReloadable() -> some View {
        modifier(HotReloadModifier())
    }
}

private struct HotReloadModifier: ViewModifier {
    #if DEBUG
    @ObserveInjection private var inject
    #endif

    func body(content: Content) -> some View {
        #if DEBUG
        content.enableInjection()
        #else
        content
        #endif
    }
}
