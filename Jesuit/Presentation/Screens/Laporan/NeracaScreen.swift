//
//  NeracaScreen.swift
//  Jesuit
//
//  Neraca (balance sheet) rendered as an accounting statement: a company
//  header, grouped sections (Harta / Kewajiban / Modal), and emphasized
//  grand-total bars. Data comes from the balance-sheet summary endpoint via
//  NeracaPresenter; pick the "as of" date from the toolbar.
//

import SwiftUI

struct NeracaScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var presenter = AppDI.shared.resolver(NeracaPresenter.self)
    @State private var showDatePicker = false
    @State private var pickerDate = Date.now

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if presenter.isLoading {
                        ProgressView().tint(.accent)
                            .frame(maxWidth: .infinity, minHeight: 240)
                    } else if let error = presenter.errorMessage {
                        stateMessage(error, systemImage: "exclamationmark.triangle")
                    } else if presenter.summary != nil {
                        header
                        statementCard
                    } else {
                        stateMessage("Neraca tidak tersedia.", systemImage: "tray")
                    }
                }
                .padding(16)
            }
            .refreshable { await presenter.load() }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Neraca")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.subtitle)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        pickerDate = presenter.asOf
                        showDatePicker = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) { datePickerSheet }
        }
        .task { await presenter.load() }
        .hotReloadable()
    }

    // MARK: - Header (company + title + date)

    private var header: some View {
        CardContainer {
            VStack(spacing: 6) {
                Image("LogoSerikatJesus")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                Text(presenter.organization)
                    .customFont(.medium, Typography.subhead)
                    .foregroundStyle(.subtitle)
                    .multilineTextAlignment(.center)
                Text("Neraca")
                    .customFont(.bold, Typography.title2)
                    .foregroundStyle(.title)
                Text(asOfText)
                    .customFont(.regular, Typography.subhead)
                    .foregroundStyle(.subtitle)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    /// "Per 24 Juni 2026" — the snapshot date, localised to Indonesian.
    private var asOfText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "d MMMM yyyy"
        return "Per \(f.string(from: presenter.asOf))"
    }

    // MARK: - Statement

    private var statementCard: some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(presenter.rows) { row($0) }
            }
        }
    }

    @ViewBuilder
    private func row(_ row: StatementRow) -> some View {
        switch row.style {
        case .section:
            Text(row.label)
                .customFont(.semibold, Typography.title2)
                .foregroundStyle(.title)
                .padding(.top, 18)
                .padding(.bottom, 8)
            Divider()

        case .line:
            amountRow(row, labelWeight: .regular, labelColor: .title, valueWeight: .regular)
                .padding(.vertical, 10)

        case .subtotal:
            VStack(spacing: 0) {
                Divider()
                amountRow(row, labelWeight: .semibold, labelColor: .title, valueWeight: .semibold)
                    .padding(.vertical, 10)
            }

        case .grandTotal:
            amountRow(row, labelWeight: .bold, labelColor: .title, valueWeight: .bold)
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.title.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.top, 8)
        }
    }

    private func amountRow(
        _ row: StatementRow,
        labelWeight: CustomFontWeight,
        labelColor: Color,
        valueWeight: CustomFontWeight
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(row.label)
                .customFont(labelWeight, Typography.body)
                .foregroundStyle(labelColor)
                .padding(.leading, CGFloat(row.indent) * 16)
            Spacer(minLength: 8)
            Text((row.amount ?? 0).asAccounting)
                .customFont(valueWeight, Typography.body)
                .foregroundStyle(.title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
    }

    // MARK: - Date picker

    private var datePickerSheet: some View {
        NavigationStack {
            VStack {
                DatePicker(
                    "Per tanggal",
                    selection: $pickerDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding()
                Spacer()
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Per tanggal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { showDatePicker = false }.foregroundStyle(.subtitle)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terapkan") {
                        showDatePicker = false
                        Task { await presenter.setDate(pickerDate) }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func stateMessage(_ text: String, systemImage: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 36))
                .foregroundStyle(.subtitle)
            Text(text)
                .customFont(.medium, Typography.body)
                .foregroundStyle(.subtitle)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, minHeight: 240)
    }
}
