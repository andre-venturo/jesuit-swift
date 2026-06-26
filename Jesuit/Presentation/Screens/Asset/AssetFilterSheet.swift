//
//  AssetFilterSheet.swift
//  Jesuit
//
//  Combined "Filter" sheet for the Aset list: a Kategori section (searchable,
//  with per-category counts) and a Status section, both single-select. Holds
//  local selection state and applies both at once via `onApply` — one network
//  reload instead of two. Reuses the `FilterBySheet` row idiom.
//

import SwiftUI

struct AssetFilterSheet: View {
    let categoryOptions: [FilterOption]
    let statusOptions: [FilterOption]
    let selectedCategoryId: String
    let selectedStatusId: String
    /// Applies the chosen `(categoryId, statusId)` (both `""` = Semua).
    let onApply: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var categoryId: String
    @State private var statusId: String
    @State private var query = ""

    init(
        categoryOptions: [FilterOption],
        statusOptions: [FilterOption],
        selectedCategoryId: String,
        selectedStatusId: String,
        onApply: @escaping (String, String) -> Void
    ) {
        self.categoryOptions = categoryOptions
        self.statusOptions = statusOptions
        self.selectedCategoryId = selectedCategoryId
        self.selectedStatusId = selectedStatusId
        self.onApply = onApply
        _categoryId = State(initialValue: selectedCategoryId)
        _statusId = State(initialValue: selectedStatusId)
    }

    private var visibleCategories: [FilterOption] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return categoryOptions }
        return categoryOptions.filter { $0.label.localizedCaseInsensitiveContains(q) }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    section(
                        "STATUS",
                        options: statusOptions,
                        selectedId: statusId,
                        onSelect: { statusId = $0 }
                    )
                    categorySection
                }
                .padding(16)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Reset") {
                        categoryId = ""
                        statusId = ""
                    }
                    .foregroundStyle(.subtitle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terapkan") {
                        onApply(categoryId, statusId)
                        dismiss()
                    }
                    .foregroundStyle(.accent)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("KATEGORI")
                .customFont(.semibold, Typography.caption)
                .foregroundStyle(.subtitle)
                .padding(.leading, 4)
            searchBar
            VStack(spacing: 12) {
                ForEach(visibleCategories) { option in
                    row(option, isSelected: option.id == categoryId) { categoryId = option.id }
                }
            }
        }
    }

    private func section(
        _ title: String,
        options: [FilterOption],
        selectedId: String,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .customFont(.semibold, Typography.caption)
                .foregroundStyle(.subtitle)
                .padding(.leading, 4)
            VStack(spacing: 12) {
                ForEach(options) { option in
                    row(option, isSelected: option.id == selectedId) { onSelect(option.id) }
                }
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass").foregroundStyle(.subtitle)
            TextField("Cari kategori", text: $query)
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
    }

    private func row(_ option: FilterOption, isSelected: Bool, onTap: @escaping () -> Void) -> some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text(option.label)
                    .customFont(.medium, Typography.body)
                    .foregroundStyle(isSelected ? .accent : .title)
                Spacer(minLength: 12)
                if let count = option.count, count > 0 {
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
            .padding(.vertical, 14)
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
