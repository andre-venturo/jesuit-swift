//
//  FilterBySheet.swift
//  Jesuit
//
//  Zoho-style "Filter Berdasarkan" bottom sheet: a card of selectable status
//  rows, the active one outlined + checkmarked, each with a live count badge.
//  Shared by the Penerimaan and Pengeluaran lists (and reusable elsewhere).
//

import SwiftUI

/// One row in `FilterBySheet`: an id, a label and an optional count badge.
struct FilterOption: Identifiable, Equatable {
    let id: String
    let label: String
    let count: Int?

    init(id: String, label: String, count: Int? = nil) {
        self.id = id
        self.label = label
        self.count = count
    }
}

/// Bottom sheet listing status filters. Selecting a row reports its id via
/// `onSelect` and dismisses.
struct FilterBySheet: View {
    let title: String
    let options: [FilterOption]
    let selectedId: String
    let onSelect: (String) -> Void
    /// Shows a search field that filters rows by label — for long option lists.
    var searchable: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    /// Options after the search query (label contains, case-insensitive).
    private var visibleOptions: [FilterOption] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard searchable, !q.isEmpty else { return options }
        return options.filter { $0.label.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(visibleOptions) { option in
                        row(option)
                    }
                }
                .padding(16)
            }
            .safeAreaInset(edge: .top) {
                if searchable { searchBar }
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.subtitle)
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.subtitle)
            TextField("Cari", text: $query)
                .font(.customFont(.regular, Typography.body))
                .foregroundStyle(.title)
                .autocorrectionDisabled()
                .keyboardDoneButton()
            if !query.isEmpty {
                Button { query = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.subtitle)
                }
            }
        }
        .padding(.horizontal, 14)
        .frame(height: 44)
        .background(Color.white.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .background(Color.background1)
    }

    private func row(_ option: FilterOption) -> some View {
        let isSelected = option.id == selectedId
        return Button {
            onSelect(option.id)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Text(option.label)
                    .customFont(.medium, Typography.body)
                    .foregroundStyle(isSelected ? .accent : .title)
                Spacer(minLength: 12)
                if let count = option.count {
                    Text("\(count)")
                        .customFont(.semibold, Typography.subhead)
                        .foregroundStyle(isSelected ? .accent : .subtitle)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background((isSelected ? Color.accentColor : Color.subtitle).opacity(0.14))
                        .clipShape(Capsule())
                }
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
