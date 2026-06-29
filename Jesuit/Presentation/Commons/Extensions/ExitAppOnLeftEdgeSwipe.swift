//
//  ExitAppOnLeftEdgeSwipe.swift
//  Jesuit
//
//  A left-edge swipe-back on a tab-root screen has nowhere to go (NavigationService
//  vetoes UIPilot's pop for the home route), so prompt to exit the app instead.
//  Applied to each tab root — a pushed detail covers the root, so this gesture stays
//  dormant under a push and the detail's own swipe-back still works.
//

import SwiftUI

private struct ExitAppOnLeftEdgeSwipe: ViewModifier {
    @State private var showExitConfirm = false

    func body(content: Content) -> some View {
        content
            .simultaneousGesture(
                DragGesture(minimumDistance: 15, coordinateSpace: .global)
                    .onEnded { value in
                        guard value.startLocation.x < 20,
                              value.translation.width > 70,
                              abs(value.translation.height) < 60
                        else { return }
                        showExitConfirm = true
                    }
            )
            .alert("Keluar dari Aplikasi", isPresented: $showExitConfirm) {
                Button("Batal", role: .cancel) {}
                Button("Keluar", role: .destructive) { exit(0) }
            } message: {
                Text("Apakah Anda yakin ingin keluar dari aplikasi?")
            }
    }
}

extension View {
    /// Turns a left-edge swipe-back on a tab-root screen into an "exit the app?" prompt.
    func exitAppOnLeftEdgeSwipe() -> some View {
        modifier(ExitAppOnLeftEdgeSwipe())
    }
}
