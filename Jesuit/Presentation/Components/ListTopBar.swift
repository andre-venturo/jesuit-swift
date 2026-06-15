//
//  ListTopBar.swift
//  Jesuit
//
//  Shared top bar for the list tabs (Customers, Penerimaan, Pengeluaran):
//  a large title with a toggleable search field, a row of filter chips, a
//  filter-sheet button and a sort button.
//

import SwiftUI

struct ListTopBar: View {
    let title: String
    let searchPlaceholder: String
    @Binding var searchText: String

    /// Chip labels and the currently selected one.
    let chips: [String]
    let selectedChip: String
    let onSelectChip: (String) -> Void

    let onToggleSort: () -> Void

    @State private var showSearch = false

    var body: some View {
        VStack(spacing: 0) {
            header
            if showSearch { searchBar }
            filterChips
            Divider().opacity(0.4)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(title)
                .customFont(.bold, 34)
                .foregroundStyle(.title)
            Spacer()
            Button {
                withAnimation { showSearch.toggle() }
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.title)
                    .frame(width: 44, height: 44)
                    .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 12)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.subtitle)
            TextField(searchPlaceholder, text: $searchText)
                .font(.customFont(.regular, 15))
                .foregroundStyle(.title)
                .autocorrectionDisabled()
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.bottom, 12)
    }

    // MARK: - Filter chips

    private var filterChips: some View {
        HStack(spacing: 12) {
            ForEach(chips, id: \.self) { label in
                chip(label)
            }
            Button {
                // Reserved for the extended filter sheet.
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.title)
                    .frame(width: 36, height: 36)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }

            Spacer()

            Button(action: onToggleSort) {
                Image(systemName: "line.3.horizontal.decrease")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.title)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 14)
    }

    private func chip(_ label: String) -> some View {
        let isActive = selectedChip == label
        return Button {
            onSelectChip(label)
        } label: {
            Text(label)
                .customFont(.medium, 17)
                .foregroundStyle(isActive ? .white : .title)
                .padding(.horizontal, 20)
                .frame(height: 40)
                .background(isActive ? Color.accentColor : Color.white.opacity(0.06))
                .clipShape(Capsule())
        }
    }
}
