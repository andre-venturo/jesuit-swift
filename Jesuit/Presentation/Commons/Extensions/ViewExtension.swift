//
//  ViewExtension.swift
//  Jesuit
//
//  Created by admin on 24/11/25.
//

import SwiftUI

extension View {
    func inPreviewNavigation() -> some View {
        NavigationStack { self }.ignoresSafeArea()
    }

    func coreTextFieldStyle() -> some View {
        self.modifier(CoreTextModifier())
    }
}
