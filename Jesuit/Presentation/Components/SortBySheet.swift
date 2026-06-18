//
//  SortBySheet.swift
//  Jesuit
//
//  Zoho-style "Urutkan" bottom sheet: a card of sort-field rows, the active one
//  outlined and showing its direction arrow (tap again to flip direction), plus
//  a footer "Selected Sorting" caption and a "Terapkan" button. Selection is
//  staged locally and committed only on Terapkan.
//

import SwiftUI

struct SortBySheet: View {
    let fields: [ReceiptSortField]
    let initialField: ReceiptSortField
    let initialDirection: SortDirection
    let onApply: (ReceiptSortField, SortDirection) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var field: ReceiptSortField
    @State private var direction: SortDirection

    init(
        fields: [ReceiptSortField] = ReceiptSortField.allCases,
        field: ReceiptSortField,
        direction: SortDirection,
        onApply: @escaping (ReceiptSortField, SortDirection) -> Void
    ) {
        self.fields = fields
        self.initialField = field
        self.initialDirection = direction
        self.onApply = onApply
        _field = State(initialValue: field)
        _direction = State(initialValue: direction)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(fields) { option in
                            row(option)
                        }
                    }
                    .padding(16)
                }
                footer
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Urutkan")
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

    /// Tapping the active field flips its direction; tapping another selects it
    /// (keeping the current direction).
    private func row(_ option: ReceiptSortField) -> some View {
        let isSelected = option == field
        return Button {
            if isSelected {
                direction.toggle()
            } else {
                field = option
            }
        } label: {
            HStack(spacing: 12) {
                Text(option.rawValue)
                    .customFont(.medium, Typography.body)
                    .foregroundStyle(isSelected ? .accent : .title)
                Spacer(minLength: 12)
                if isSelected {
                    Text(direction.label)
                        .customFont(.regular, Typography.subhead)
                        .foregroundStyle(.subtitle)
                    Image(systemName: direction.systemImage)
                        .font(.system(size: 15, weight: .semibold))
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

    private var footer: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Urutan Terpilih")
                    .customFont(.regular, Typography.caption)
                    .foregroundStyle(.subtitle)
                Text("\(field.rawValue) (\(direction.label))")
                    .customFont(.semibold, Typography.subhead)
                    .foregroundStyle(.title)
            }
            Spacer()
            Button {
                onApply(field, direction)
                dismiss()
            } label: {
                Text("Terapkan")
                    .customFont(.semibold, Typography.body)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 28)
                    .padding(.vertical, 12)
                    .background(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }
}
