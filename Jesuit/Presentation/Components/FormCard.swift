//
//  FormCard.swift
//  Jesuit
//
//  Zoho-style grouped form building blocks: a section header above a rounded
//  card, whose rows are "label on the left, value/control on the right" with a
//  trailing chevron for tappable rows and inset dividers between them. Uses the
//  app's existing theme tokens (textFieldBG / title / subtitle / accent).
//

import SwiftUI

/// A grouped form section: an optional header above a rounded card. Rows are
/// supplied by the caller (typically `FormRow` / `FormPickerRow` / `FormDateRow`)
/// in a `VStack(spacing: 0)`; each row draws its own bottom divider.
struct FormCard<Content: View>: View {
    var title: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title.uppercased())
                    .customFont(.semibold, Typography.caption)
                    .foregroundStyle(.subtitle)
                    .padding(.leading, 4)
            }
            VStack(spacing: 0) { content }
                .background(Color.textFieldBG)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
    }
}

/// Inset divider between form rows.
struct FormRowDivider: View {
    var body: some View {
        Divider().opacity(0.4).padding(.leading, 16)
    }
}

/// Shared row chrome: a label on the left (red when `required`) and trailing
/// content on the right, with an optional chevron and tap action.
private struct FormRowShell<Trailing: View>: View {
    let label: String
    var required: Bool = false
    var showChevron: Bool = false
    var onTap: (() -> Void)?
    @ViewBuilder let trailing: Trailing

    var body: some View {
        let row = HStack(spacing: 12) {
            Text(label)
                .customFont(.medium, Typography.body)
                .foregroundStyle(required ? Color.expense : Color.title)
            Spacer(minLength: 12)
            trailing
            if showChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.subtitle)
            }
        }
        .padding(.horizontal, 16)
        .frame(minHeight: 52)

        if let onTap {
            Button(action: onTap) { row.contentShape(Rectangle()) }
                .buttonStyle(.plain)
        } else {
            row
        }
    }
}

/// A tappable row that opens a searchable `SelectionSheet`. Shows the selected
/// option's title (or a placeholder) on the right.
struct FormPickerRow: View {
    let label: String
    var required: Bool = false
    let options: [SelectionOption]
    let selectedId: String?
    var placeholder: String = "Pilih"
    var sheetTitle: String = "Pilih"
    var searchPrompt: String = "Cari…"
    var showDivider: Bool = true
    let onSelect: (String) -> Void

    @State private var showSheet = false

    private var selectedTitle: String? {
        options.first { $0.id == selectedId }?.title
    }

    var body: some View {
        VStack(spacing: 0) {
            FormRowShell(label: label, required: required, showChevron: true,
                         onTap: { if !options.isEmpty { showSheet = true } }) {
                Text(selectedTitle ?? placeholder)
                    .customFont(.regular, Typography.body)
                    .foregroundStyle(selectedTitle == nil ? .subtitle : .accent)
                    .lineLimit(1)
            }
            if showDivider { FormRowDivider() }
        }
        .sheet(isPresented: $showSheet) {
            SelectionSheet(
                title: sheetTitle,
                searchPrompt: searchPrompt,
                options: options,
                selectedId: selectedId,
                onSelect: { id in onSelect(id); showSheet = false }
            )
        }
    }
}

/// An inline text-entry row: label on the left, right-aligned `TextField`.
struct FormFieldRow: View {
    let label: String
    var required: Bool = false
    @Binding var text: String
    var placeholder: String = "Ketik"
    var keyboard: UIKeyboardType = .default
    var showDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            FormRowShell(label: label, required: required) {
                TextField(
                    "",
                    text: $text,
                    prompt: Text(placeholder).foregroundStyle(Color.subtitle)
                )
                .font(.customFont(.regular, Typography.body))
                .foregroundStyle(.title)
                .multilineTextAlignment(.trailing)
                .keyboardType(keyboard)
                .textInputAutocapitalization(keyboard == .emailAddress ? .never : .sentences)
                .autocorrectionDisabled(keyboard == .emailAddress)
            }
            if showDivider { FormRowDivider() }
        }
    }
}

/// A date row: label on the left, compact `DatePicker` pill on the right.
struct FormDateRow: View {
    let label: String
    var required: Bool = false
    @Binding var date: Date
    var showDivider: Bool = true

    var body: some View {
        VStack(spacing: 0) {
            FormRowShell(label: label, required: required) {
                DatePicker("", selection: $date, displayedComponents: .date)
                    .labelsHidden()
                    .tint(.accent)
            }
            if showDivider { FormRowDivider() }
        }
    }
}

/// A toggle row: label on the left, `Toggle` on the right.
struct FormToggleRow: View {
    let label: String
    @Binding var isOn: Bool
    var showDivider: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            FormRowShell(label: label) {
                Toggle("", isOn: $isOn).labelsHidden().tint(.accent)
            }
            if showDivider { FormRowDivider() }
        }
    }
}
