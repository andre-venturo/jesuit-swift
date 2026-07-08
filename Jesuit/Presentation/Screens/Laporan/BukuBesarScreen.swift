//
//  BukuBesarScreen.swift
//  Jesuit
//
//  Buku Besar (general ledger): one ledger card per cash account for the
//  selected period — opening balance, movements with a running balance,
//  and totals. Pushed from LaporanIndexScreen.
//

import SwiftUI

struct BukuBesarScreen: View {
    @Injected private var session: AuthSession
    @State private var presenter = AppDI.shared.resolver(BukuBesarPresenter.self)
    @State private var showCustomRange = false
    @State private var showAccountPicker = false

    private let colGap: CGFloat = 14

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                chipRow
                if presenter.isLoading {
                    ProgressView().tint(.accent)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = presenter.errorMessage {
                    ReportStateMessage(text: error, systemImage: "exclamationmark.triangle")
                } else if let ledgers = presenter.ledgers {
                    ReportHeader(
                        organization: session.organization,
                        title: "Buku Besar",
                        subtitle: reportRangeText(presenter.period.range)
                    )
                    ForEach(ledgers) { ledgerCard($0) }
                } else {
                    ReportStateMessage(text: "Tidak ada transaksi pada periode ini.", systemImage: "tray")
                }
            }
            .padding(16)
        }
        .refreshable { await presenter.load(forceReload: true) }
        .background(Color.background1.ignoresSafeArea())
        .navigationTitle("Buku Besar")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCustomRange) {
            CashFlowRangeSheet(
                initialRange: presenter.period.range,
                onApply: { start, end in presenter.period.applyCustomRange(start: start, end: end) }
            )
        }
        .sheet(isPresented: $showAccountPicker) {
            FilterBySheet(
                title: "Akun",
                options: [FilterOption(id: "", label: "Semua Akun")]
                    + presenter.accountOptions.map { FilterOption(id: $0.id, label: $0.name) },
                selectedId: presenter.accountFilter ?? "",
                onSelect: { id in presenter.accountFilter = id.isEmpty ? nil : id },
                searchable: true
            )
        }
        .task { await presenter.load() }
        .hotReloadable()
    }

    private var chipRow: some View {
        HStack(spacing: 8) {
            PeriodMenuChip(period: presenter.period, showCustomRange: $showCustomRange)
            Button { showAccountPicker = true } label: {
                ReportChip(icon: "creditcard", text: presenter.accountLabelText,
                           active: presenter.accountFilter != nil)
            }
        }
    }

    // MARK: - Ledger card

    private func ledgerCard(_ ledger: LedgerAccount) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(ledger.name)
                .customFont(.semibold, Typography.headline)
                .foregroundStyle(.title)
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        headerCell("Tanggal")
                        headerCell("No. Transaksi")
                        headerCell("Deskripsi")
                        headerCell("Debit", align: .trailing)
                        headerCell("Kredit", align: .trailing)
                        headerCell("Saldo", align: .trailing)
                    }
                    Divider()
                    openingRow(ledger)
                    Divider().opacity(0.35)
                    ForEach(ledger.rows) { row in
                        GridRow {
                            metaCell(dateText(row.date))
                            primaryCell(row.number)
                            metaCell(row.description.isEmpty ? "–" : row.description, maxWidth: 260)
                            amountCell(row.debit)
                            amountCell(row.kredit)
                            amountCell(row.saldo, dashWhenZero: false)
                        }
                        Divider().opacity(0.35)
                    }
                    totalRow(ledger)
                }
            }
        }
    }

    /// "Saldo Awal" pseudo-row: balance carried into the period.
    private func openingRow(_ ledger: LedgerAccount) -> some View {
        GridRow {
            metaCell("")
            metaCell("Saldo Awal")
            metaCell("")
            metaCell("")
            metaCell("")
            amountCell(ledger.opening, dashWhenZero: false)
        }
    }

    private func totalRow(_ ledger: LedgerAccount) -> some View {
        GridRow {
            Text("Saldo Akhir")
                .font(.customFont(.bold, ListMetrics.titleSize))
                .foregroundStyle(.title)
                .padding(.trailing, colGap)
                .padding(.vertical, 12)
                .gridCellColumns(3)
                .frame(maxWidth: .infinity, alignment: .leading)
            amountCell(ledger.totalDebit)
                .frame(maxWidth: .infinity, alignment: .trailing)
            amountCell(ledger.totalKredit)
                .frame(maxWidth: .infinity, alignment: .trailing)
            amountCell(ledger.closing, dashWhenZero: false)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .background(Color.title.opacity(0.05))
    }

    // MARK: - Cells (LaporanScreen's ledger scale)

    private func headerCell(_ text: String, align: HorizontalAlignment = .leading) -> some View {
        Text(text)
            .font(.customFont(.semibold, ListMetrics.metaSize))
            .foregroundStyle(.subtitle)
            .textCase(.uppercase)
            .lineLimit(1)
            .padding(.trailing, colGap)
            .padding(.bottom, 8)
            .gridColumnAlignment(align)
    }

    private func primaryCell(_ text: String) -> some View {
        cell(text, weight: .bold, size: ListMetrics.titleSize, color: .title)
    }

    private func metaCell(_ text: String, maxWidth: CGFloat? = nil) -> some View {
        cell(text, weight: .regular, size: ListMetrics.metaSize, color: .subtitle, maxWidth: maxWidth)
    }

    private func cell(_ text: String, weight: CustomFontWeight, size: CGFloat, color: Color, maxWidth: CGFloat? = nil) -> some View {
        Text(text)
            .customFont(weight, size)
            .foregroundStyle(color)
            .lineLimit(1)
            .monospacedDigit()
            .frame(maxWidth: maxWidth, alignment: .leading)
            .padding(.trailing, colGap)
            .padding(.vertical, ListMetrics.rowVerticalPadding)
    }

    private func amountCell(_ amount: Double, dashWhenZero: Bool = true) -> some View {
        Text(amount == 0 && dashWhenZero ? "–" : amount.asGrouped)
            .customFont(.bold, ListMetrics.titleSize)
            .monospacedDigit()
            .foregroundStyle(amount == 0 && dashWhenZero ? Color.subtitle.opacity(0.5) : .title)
            .lineLimit(1)
            .padding(.trailing, colGap)
            .padding(.vertical, ListMetrics.rowVerticalPadding)
    }

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }
}
