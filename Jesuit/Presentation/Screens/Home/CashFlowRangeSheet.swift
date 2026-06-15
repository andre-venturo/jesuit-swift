//
//  CashFlowRangeSheet.swift
//  Jesuit
//
//  Custom date-range picker for the dashboard Cash Flow card. Two date pickers
//  (start/end) feeding the dashboard endpoints' start_date/end_date params.
//

import SwiftUI

struct CashFlowRangeSheet: View {
    let initialRange: (start: Date, end: Date)
    let onApply: (Date, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var start: Date
    @State private var end: Date

    init(initialRange: (start: Date, end: Date), onApply: @escaping (Date, Date) -> Void) {
        self.initialRange = initialRange
        self.onApply = onApply
        _start = State(initialValue: initialRange.start)
        _end = State(initialValue: initialRange.end)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    field("Start date") {
                        DatePicker("", selection: $start, displayedComponents: .date)
                            .labelsHidden()
                            .tint(.accent)
                            .onChange(of: start) { _, newStart in
                                // Keep the end picker in the start's month: clamp
                                // it into [start, end-of-that-month].
                                end = clampEnd(end, toMonthOf: newStart)
                            }
                    }
                    field("End date") {
                        DatePicker("", selection: $end, in: start..., displayedComponents: .date)
                            .labelsHidden()
                            .tint(.accent)
                    }

                    Button {
                        onApply(start, end)
                        dismiss()
                    } label: {
                        Text("Apply")
                            .customFont(.medium, 18)
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding(.top, 8)
                }
                .padding(20)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Custom Range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }.foregroundStyle(.subtitle)
                }
            }
        }
    }

    /// Snaps `date` into the calendar month of `reference`: if it falls outside
    /// that month it is moved to the reference day, otherwise kept as-is. Keeps
    /// the end picker showing the start's month after a start change.
    private func clampEnd(_ date: Date, toMonthOf reference: Date) -> Date {
        let cal = Calendar.current
        if cal.isDate(date, equalTo: reference, toGranularity: .month), date >= reference {
            return date
        }
        return reference
    }

    private func field<Content: View>(
        _ title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .customFont(.medium, 15)
                .foregroundStyle(.subtitle)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
