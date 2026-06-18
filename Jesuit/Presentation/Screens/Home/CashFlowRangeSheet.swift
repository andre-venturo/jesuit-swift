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
                    field("Tanggal Mulai") {
                        DatePicker("", selection: $start, displayedComponents: .date)
                            .labelsHidden()
                            .tint(.accent)
                            .onChange(of: start) { _, newStart in
                                if end < newStart { end = newStart }
                            }
                    }
                    field("Tanggal Akhir") {
                        DatePicker("", selection: $end, in: start..., displayedComponents: .date)
                            .labelsHidden()
                            .tint(.accent)
                    }

                    Button {
                        onApply(start, end)
                        dismiss()
                    } label: {
                        Text("Terapkan")
                            .customFont(.medium, Typography.headline)
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
            .navigationTitle("Rentang Khusus")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.subtitle)
                }
            }
        }
    }

    private func field<Content: View>(
        _ title: String,
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .customFont(.medium, Typography.body)
                .foregroundStyle(.subtitle)
            content()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
