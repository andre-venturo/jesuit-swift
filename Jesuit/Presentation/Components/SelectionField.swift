//
//  SelectionField.swift
//  Jesuit
//
//  A text-field-styled selector that opens a searchable bottom sheet of options,
//  replacing the inline `Menu {}` dropdowns across the create/edit forms. The
//  field shows the current selection (or a placeholder); tapping presents
//  `SelectionSheet`, a list of rows filtered live by a search bar.
//

import SwiftUI

/// A pickable option: an identifiable value with a primary title and an
/// optional subtitle (e.g. an account code shown above its name).
struct SelectionOption: Identifiable, Equatable {
    let id: String
    let title: String
    var subtitle: String?
    /// Optional trailing value (e.g. an account's balance), pre-formatted.
    var trailing: String?

    init(id: String, title: String, subtitle: String? = nil, trailing: String? = nil) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    /// Maps a chart-of-accounts entry: name as title, account code as subtitle,
    /// and the current balance (when present) as the trailing value.
    init(account: AccountDTO) {
        self.init(
            id: account.id,
            title: account.name,
            subtitle: account.code,
            trailing: account.balance.map { $0.asCurrency(account.currencyCode) }
        )
    }
}

/// Text-field-styled selector. Tap opens a searchable bottom sheet; selecting a
/// row reports its id via `onSelect`.
struct SelectionField: View {
    let options: [SelectionOption]
    /// Currently selected option id (nil → placeholder shown).
    let selectedId: String?
    let placeholder: String
    /// Title shown on the bottom sheet's navigation bar.
    var sheetTitle: String = "Pilih"
    var searchPrompt: String = "Cari…"
    let onSelect: (String) -> Void

    @State private var showSheet = false

    private var selectedTitle: String? {
        options.first { $0.id == selectedId }?.title
    }

    var body: some View {
        Button {
            showSheet = true
        } label: {
            HStack {
                Text(selectedTitle ?? placeholder)
                    .customFont(.regular, Typography.body)
                    .foregroundStyle(selectedTitle == nil ? .subtitle : .title)
                    .lineLimit(1)
                Spacer()
                Image(systemName: "chevron.down")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.subtitle)
            }
            .coreTextFieldStyle()
        }
        .buttonStyle(.plain)
        .disabled(options.isEmpty)
        .sheet(isPresented: $showSheet) {
            SelectionSheet(
                title: sheetTitle,
                searchPrompt: searchPrompt,
                options: options,
                selectedId: selectedId,
                onSelect: { id in
                    onSelect(id)
                    showSheet = false
                }
            )
        }
    }
}

/// The searchable bottom sheet presented by `SelectionField`. A search bar atop a
/// scrolling card of rows; the active option carries a trailing checkmark.
struct SelectionSheet: View {
    let title: String
    let searchPrompt: String
    let options: [SelectionOption]
    let selectedId: String?
    let onSelect: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var query = ""

    private var filtered: [SelectionOption] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return options }
        return options.filter { option in
            option.title.localizedCaseInsensitiveContains(trimmed)
                || (option.subtitle?.localizedCaseInsensitiveContains(trimmed) ?? false)
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                searchBar

                ScrollView {
                    if filtered.isEmpty {
                        Text("Tidak ada hasil")
                            .customFont(.regular, Typography.body)
                            .foregroundStyle(.subtitle)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                    } else {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filtered.enumerated()), id: \.element.id) { index, option in
                                row(option)
                                RowDivider(index: index, count: filtered.count)
                            }
                        }
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
            .padding(16)
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }
                        .foregroundStyle(.subtitle)
                }
            }
        }
        .presentationDetents([.large, .medium])
        .presentationDragIndicator(.visible)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.subtitle)
            TextField(searchPrompt, text: $query)
                .font(Font.customFont(.regular, Typography.body))
                .foregroundStyle(.title)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.subtitle)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(.textFieldStroke, lineWidth: 1)
        )
    }

    private func row(_ option: SelectionOption) -> some View {
        let isSelected = option.id == selectedId
        return Button {
            onSelect(option.id)
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(option.title)
                        .customFont(.medium, Typography.body)
                        .foregroundStyle(isSelected ? .accent : .title)
                        .lineLimit(1)
                    if let subtitle = option.subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .customFont(.regular, Typography.subhead)
                            .foregroundStyle(.subtitle)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 12)
                if let trailing = option.trailing, !trailing.isEmpty {
                    Text(trailing)
                        .customFont(.regular, Typography.subhead)
                        .foregroundStyle(.subtitle)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
