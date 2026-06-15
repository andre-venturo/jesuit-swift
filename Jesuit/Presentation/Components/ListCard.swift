//
//  ListCard.swift
//  Jesuit
//
//  A rounded card that stacks rows with separators.
//

import SwiftUI

struct ListCard<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        VStack(spacing: 0) { content() }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}

/// Inserts a leading-inset divider between rows of an indexed collection.
struct RowDivider: View {
    let index: Int
    let count: Int
    var inset: CGFloat = 16

    var body: some View {
        if index < count - 1 {
            Divider().padding(.leading, inset)
        }
    }
}
