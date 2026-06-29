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

    /// Opens the extended "Filter Berdasarkan" sheet (the chevron-down button).
    let onOpenFilter: () -> Void
    /// Opens the "Urutkan" sort sheet. Nil hides the sort button (e.g. lists the
    /// API returns in a fixed order with no sort param).
    var onOpenSort: (() -> Void)?

    /// Opens a period picker (a calendar button beside the filter chevron). Nil hides
    /// it. `periodActive` tints it when a period filter is applied.
    var onOpenPeriod: (() -> Void)?
    var periodActive: Bool = false

    /// Hide the big in-content title when the screen shows it in a native nav bar
    /// instead (pushed pages like Transfer/Asset, which get a system inline title
    /// + native back chevron). The search/filter row still renders.
    var showTitle: Bool = true

    /// Hide the in-bar magnifier button — used when the screen puts a search action in
    /// its native nav bar instead (Asset/Transfer). The search FIELD still toggles.
    var showSearchButton: Bool = true

    /// External control of the search field's visibility, for screens that toggle it
    /// from the nav bar. Nil = manage it internally via the in-bar button.
    var externalShowSearch: Binding<Bool>? = nil

    @State private var internalShowSearch = false
    @FocusState private var searchFocused: Bool

    private var showSearch: Binding<Bool> { externalShowSearch ?? $internalShowSearch }

    var body: some View {
        VStack(spacing: 0) {
            if showTitle || showSearchButton {
                header
            }
            if showSearch.wrappedValue { searchBar }
            filterChips
            Divider().opacity(0.4)
        }
        .onChange(of: showSearch.wrappedValue) { _, visible in
            searchFocused = visible
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 10) {
            if showTitle {
                Text(title)
                    .customFont(.bold, Typography.display)
                    .foregroundStyle(.title)
            }
            Spacer()
            if showSearchButton {
                Button {
                    withAnimation { showSearch.wrappedValue.toggle() }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.title)
                        .frame(width: 44, height: 44)
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))
                }
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
                .font(.customFont(.regular, Typography.body))
                .foregroundStyle(.title)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .focused($searchFocused)
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
        HStack(spacing: 10) {
            // Chips scroll horizontally so full labels stay readable instead of
            // truncating ("Belu…" / "Men…") when squeezed against the buttons.
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(chips, id: \.self) { label in
                        chip(label)
                    }
                }
            }

            if let onOpenPeriod {
                Button(action: onOpenPeriod) {
                    Image(systemName: "calendar")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(periodActive ? Color.accentColor : .title)
                        .frame(width: 32, height: 32)
                        .overlay(Circle().stroke(periodActive ? Color.accentColor : Color.white.opacity(0.18), lineWidth: 1))
                }
            }

            Button(action: onOpenFilter) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.title)
                    .frame(width: 32, height: 32)
                    .overlay(Circle().stroke(Color.white.opacity(0.18), lineWidth: 1))
            }

            if let onOpenSort {
                Button(action: onOpenSort) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.title)
                }
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
                .customFont(.medium, Typography.subhead)
                .foregroundStyle(isActive ? .white : .title)
                .lineLimit(1)
                .fixedSize()
                .padding(.horizontal, 14)
                .frame(height: 32)
                .background(isActive ? Color.accentColor : Color.white.opacity(0.06))
                .clipShape(Capsule())
        }
    }
}
