//
//  StatusFilterTabs.swift
//  Jesuit
//
//  Horizontal scrolling status filter with count badges, used to scope the
//  Penerimaan list by approval state.
//

import SwiftUI

struct StatusFilterTabs: View {
    @Binding var selection: ReceiptStatus?
    /// Count provider for each tab (`nil` == "Semua").
    let count: (ReceiptStatus?) -> Int

    /// Tab order: Semua first, then each status.
    private var tabs: [ReceiptStatus?] { [nil] + ReceiptStatus.allCases }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 24) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { _, status in
                    tab(status)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    @ViewBuilder
    private func tab(_ status: ReceiptStatus?) -> some View {
        let isSelected = selection == status
        let tint = status?.tint ?? .title

        Button {
            withAnimation(.easeInOut(duration: 0.15)) { selection = status }
        } label: {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    Text(status?.rawValue ?? "Semua")
                        .customFont(isSelected ? .semibold : .medium, Typography.body)
                        .foregroundStyle(isSelected ? .title : .subtitle)

                    Text("\(count(status))")
                        .customFont(.semibold, Typography.caption)
                        .foregroundStyle(isSelected ? Color.background1 : tint)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 2)
                        .background(isSelected ? tint : tint.opacity(0.15))
                        .clipShape(Capsule())
                }
                Rectangle()
                    .fill(isSelected ? Color.title : .clear)
                    .frame(height: 2)
            }
            .fixedSize()
        }
        .buttonStyle(.plain)
    }
}
