//
//  CardContainer.swift
//  Jesuit
//
//  Reusable rounded card surface for dashboard sections.
//

import SwiftUI

struct CardContainer<Content: View>: View {
    var padding: CGFloat = 16
    @ViewBuilder var content: () -> Content

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 2)
    }
}

struct SectionHeader: View {
    let title: LocalizedStringKey
    var action: LocalizedStringKey?

    var body: some View {
        HStack {
            Text(title)
                .customFont(.semibold, Typography.headline)
                .foregroundStyle(.title)
            Spacer()
            if let action {
                Button(action: {}) {
                    Text(action)
                        .customFont(.medium, Typography.callout)
                        .foregroundStyle(.mySecondary)
                }
            }
        }
    }
}
