//
//  CurrencyField.swift
//  Jesuit
//
//  Rupiah amount input. Binds to a digits-only string (`amountText`) but always
//  displays grouped thousands (e.g. `1.200.000`). Uses a local display buffer so
//  reformatting survives SwiftUI's TextField text coordinator (a transforming
//  Binding alone reformats unreliably and lets digits append onto stale text).
//

import SwiftUI

struct CurrencyField: View {
    /// Source of truth: digits only, e.g. "1200000".
    @Binding var digits: String

    @State private var display = ""

    var body: some View {
        HStack {
            Text("Rp")
                .customFont(.medium, Typography.body)
                .foregroundStyle(.subtitle)
            TextField(
                "",
                text: $display,
                prompt: Text("0").customFont(.regular, Typography.body).foregroundStyle(.subtitle)
            )
            .font(.customFont(.regular, Typography.body))
            .foregroundStyle(.title)
            .keyboardType(.numberPad)
            .keyboardDoneButton()
            .onChange(of: display) { _, newValue in
                let onlyDigits = newValue.filter(\.isNumber)
                digits = onlyDigits
                let grouped = onlyDigits.groupedThousands
                // Reassign only when it actually changed, to avoid a set→get loop.
                if grouped != newValue { display = grouped }
            }
        }
        .coreTextFieldStyle()
        .onAppear { display = digits.groupedThousands }
    }
}
