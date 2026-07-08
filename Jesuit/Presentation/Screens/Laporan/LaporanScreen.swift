//
//  LaporanScreen.swift
//  Jesuit
//
//  Laporan Arus Kas (cash journal): pick a period and read every in-range
//  transaction as a Jurnal Umum-style table — penerimaan posts to Debit,
//  pengeluaran to Kredit — with a company header and PDF/CSV export. All
//  computed from the cash-transactions records via LaporanPresenter.
//

import SwiftUI

struct LaporanScreen: View {
    @Injected private var session: AuthSession
    @State private var presenter = AppDI.shared.resolver(LaporanPresenter.self)
    @State private var showCustomRange = false
    @State private var showFilters = false
    @State private var exportItem: ExportItem?
    @State private var previewItem: ExportItem?

    /// Identifiable+Hashable wrapper so the CSV share sheet and the pushed PDF
    /// preview can both be driven by a URL item.
    private struct ExportItem: Identifiable, Hashable { let id = UUID(); let url: URL }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                filterRow
                if presenter.isLoading {
                    ProgressView().tint(.accent)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = presenter.errorMessage {
                    stateMessage(error, systemImage: "exclamationmark.triangle")
                } else if let summary = presenter.summary {
                    reportHeader
                    journalCard(summary)
                } else {
                    stateMessage("Tidak ada transaksi pada periode ini.", systemImage: "tray")
                }
            }
            .padding(16)
        }
        .refreshable { await presenter.load(forceReload: true) }
        .background(Color.background1.ignoresSafeArea())
        .navigationTitle("Laporan")
        .navigationBarTitleDisplayMode(.inline)
        // Tab bar is hidden by MoreScreen (the push root) while this page is up —
        // owning the modifier here would blink the bar on pop-back.
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                if let summary = presenter.summary {
                    exportMenu(summary)
                }
            }
        }
        .sheet(isPresented: $showFilters) { filterSheet }
        .sheet(isPresented: $showCustomRange) {
            CashFlowRangeSheet(
                initialRange: presenter.summaryRange,
                onApply: { start, end in presenter.applyCustomRange(start: start, end: end) }
            )
        }
        .sheet(item: $exportItem) { item in
            ShareSheet(items: [item.url])
        }
        .navigationDestination(item: $previewItem) { item in
            PDFPreviewPage(url: item.url)
        }
        .task { await presenter.load() }
        .hotReloadable()
    }

    // MARK: - Report header (company + title + date range)

    private var reportHeader: some View {
        VStack(spacing: 4) {
            Text(session.organization)
                .customFont(.regular, ListMetrics.metaSize)
                .foregroundStyle(.subtitle)
            Text(ReportExporter.title)
                .customFont(.semibold, Typography.title2)
                .foregroundStyle(.title)
            Text(rangeText)
                .customFont(.regular, ListMetrics.metaSize)
                .foregroundStyle(.subtitle)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var rangeText: String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "dd MMM yyyy"
        let range = presenter.summaryRange
        return "\(f.string(from: range.start)) — \(f.string(from: range.end))"
    }

    // MARK: - Journal table

    /// Column gap, applied as trailing padding inside each cell so the totals
    /// bands (per-cell backgrounds) stay contiguous with zero grid spacing.
    private let colGap: CGFloat = 14
    /// Deskripsi is the one free-text column — cap it so a paragraph-length
    /// description can't blow the table width out; everything else auto-sizes.
    private let descMaxWidth: CGFloat = 260

    /// `Grid` sizes each column to its widest cell, so no cell ever truncates
    /// (except capped Deskripsi) — the whole table scrolls horizontally.
    private func journalCard(_ summary: ReportSummary) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                columnHeader
                Divider()
                ForEach(summary.journalEntries) { entry in
                    journalRow(entry)
                    Divider().opacity(0.35)
                }
                Color.clear.frame(height: 8).gridCellUnsizedAxes(.horizontal)
                totalsRow(summary)
                Color.clear.frame(height: 4).gridCellUnsizedAxes(.horizontal)
                saldoRow(summary)
            }
        }
    }

    private var columnHeader: some View {
        GridRow {
            headerCell("Tanggal")
            headerCell("No. Transaksi")
            headerCell("Akun")
            headerCell("Deskripsi")
            headerCell("Debit", align: .trailing)
            headerCell("Kredit", align: .trailing)
        }
    }

    /// `align` also fixes the whole column's alignment (amounts trail).
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

    /// Same two-tier scale as the list rows (CashReceiptRow/ExpenseRow):
    /// primary (number, amounts) = bold titleSize, meta = regular metaSize.
    private func journalRow(_ entry: JournalEntry) -> some View {
        GridRow {
            metaCell(dateText(entry.date))
            primaryCell(entry.number)
            metaCell(entry.account)
            metaCell(entry.description.isEmpty ? "–" : entry.description, maxWidth: descMaxWidth)
            amountCell(entry.debit)
            amountCell(entry.kredit)
        }
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

    /// One amount cell: the grouped number when non-zero, else a blank dash.
    private func amountCell(_ amount: Double, bold: Bool = true) -> some View {
        Text(amount != 0 ? amount.asGrouped : "–")
            .customFont(bold ? .bold : .regular, ListMetrics.titleSize)
            .monospacedDigit()
            .foregroundStyle(amount == 0 ? Color.subtitle.opacity(0.5) : .title)
            .lineLimit(1)
            .padding(.trailing, colGap)
            .padding(.vertical, ListMetrics.rowVerticalPadding)
    }

    /// Column subtotals on a soft shaded band (the reference's "Total" row).
    /// Cells fill their columns so the per-cell backgrounds form one band.
    private func totalsRow(_ summary: ReportSummary) -> some View {
        GridRow {
            Text("Total")
                .font(.customFont(.bold, ListMetrics.titleSize))
                .foregroundStyle(.title)
                .padding(.trailing, colGap)
                .padding(.vertical, 12)
                .gridCellColumns(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            amountCell(summary.penerimaanTotal, bold: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
            amountCell(summary.pengeluaranTotal, bold: true)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .background(Color.title.opacity(0.05))
    }

    /// The balancing figure (Debit − Kredit) on a stronger band — the grand total.
    private func saldoRow(_ summary: ReportSummary) -> some View {
        GridRow {
            Text("Saldo")
                .font(.customFont(.bold, ListMetrics.titleSize))
                .textCase(.uppercase)
                .foregroundStyle(.title)
                .padding(.trailing, colGap)
                .padding(.vertical, 12)
                .gridCellColumns(4)
                .frame(maxWidth: .infinity, alignment: .leading)
            amountCell(summary.net, bold: true)
                .gridCellColumns(2)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .background(Color.title.opacity(0.09))
    }

    private func dateText(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }

    // MARK: - Export

    private func exportMenu(_ summary: ReportSummary) -> some View {
        Menu {
            Button { export(summary, as: .pdf) } label: {
                Label("Cetak PDF", systemImage: "doc.richtext")
            }
            Button { export(summary, as: .csv) } label: {
                Label("Export Excel (CSV)", systemImage: "tablecells")
            }
        } label: {
            Image(systemName: "square.and.arrow.up").foregroundStyle(.accent)
        }
    }

    private enum ExportKind { case pdf, csv }

    private func export(_ summary: ReportSummary, as kind: ExportKind) {
        let org = session.organization
        let label = presenter.steppedLabel
        do {
            switch kind {
            case .pdf:
                // Push the preview page first (its share button handles print/share).
                let url = try ReportExporter.pdfURL(summary: summary, orgName: org, periodLabel: label)
                previewItem = ExportItem(url: url)
            case .csv:
                let url = try ReportExporter.csvURL(summary: summary, orgName: org, periodLabel: label)
                exportItem = ExportItem(url: url)
            }
        } catch {
            // ponytail: export-to-temp failure is not worth a dialog; user can retry
        }
    }

    // MARK: - Period bar

    /// Chip row at the top of the content — capsule buttons (same style as the
    /// list tabs' filter chips) so the period/filter affordance is obvious.
    private var filterRow: some View {
        HStack(spacing: 8) {
            periodMenu
            filterChip
        }
    }

    /// Period picker as a Menu whose label is a calendar chip.
    private var periodMenu: some View {
        Menu {
            // Optional selection: nothing is checked while a custom range is
            // active — the checkmark moves to "Rentang Khusus…" below.
            Picker("Periode", selection: Binding<CashFlowPeriod?>(
                get: { presenter.hasCustomRange ? nil : presenter.cashFlowPeriod },
                set: { if let period = $0 { presenter.cashFlowPeriod = period } }
            )) {
                ForEach(CashFlowPeriod.allCases) { period in
                    Text(period.rawValue).tag(Optional(period))
                }
            }
            .menuOrder(.fixed)
            Divider()
            Button {
                showCustomRange = true
            } label: {
                Label("Rentang Khusus…", systemImage: presenter.hasCustomRange ? "checkmark" : "calendar")
            }
        } label: {
            chipLabel("calendar", presenter.steppedLabel, active: false)
        }
        .animation(.snappy, value: presenter.steppedLabel)
    }

    /// Accent-filled while any filter is active (same active look as list chips).
    private var filterChip: some View {
        Button { showFilters = true } label: {
            chipLabel("line.3.horizontal.decrease", "Filter", active: presenter.hasActiveFilters)
        }
        .animation(.snappy, value: presenter.hasActiveFilters)
    }

    private func chipLabel(_ systemImage: String, _ text: String, active: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .medium))
            Text(text)
                .customFont(.medium, Typography.subhead)
                .lineLimit(1)
        }
        .foregroundStyle(active ? .white : .title)
        .padding(.horizontal, 14)
        .frame(height: 32)
        .background(active ? Color.accentColor : Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    // MARK: - Filters

    /// Branch/account picker options: "Semua" + the ids present in the loaded
    /// records, plus the ACTIVE filter as a fallback row when a refresh dropped
    /// its id from the record set — otherwise the row would show the "Pilih"
    /// placeholder while the filter still silently applies.
    private var branchPickerOptions: [SelectionOption] {
        var options = [SelectionOption(id: "", title: "Semua Cabang & Unit")]
            + presenter.branchOptions.map { SelectionOption(id: $0.id, title: $0.name) }
        if let id = presenter.branchFilter, !options.contains(where: { $0.id == id }) {
            options.append(SelectionOption(id: id, title: presenter.branchLabelText))
        }
        return options
    }

    private var accountPickerOptions: [SelectionOption] {
        var options = [SelectionOption(id: "", title: "Semua Akun")]
            + presenter.accountOptions.map { SelectionOption(id: $0.id, title: $0.name) }
        if let id = presenter.accountFilter, !options.contains(where: { $0.id == id }) {
            options.append(SelectionOption(id: id, title: presenter.accountLabelText))
        }
        return options
    }

    /// Bottom sheet with a grouped card of picker rows (same look as the create/
    /// edit forms). Each row opens its own searchable SelectionSheet; changes
    /// apply live, so "Selesai" is pure dismissal.
    private var filterSheet: some View {
        NavigationStack {
            ScrollView {
                // The prepended "Semua" row guarantees options.count >= 2, which
                // keeps FormPickerRow's auto-select-single-option behavior from
                // silently applying a filter when only one branch/account exists.
                FormCard {
                    FormPickerRow(
                        label: "Status",
                        options: [SelectionOption(id: "", title: "Semua Status")]
                            + presenter.statusOptions.map { SelectionOption(id: $0.rawValue, title: $0.rawValue) },
                        selectedId: presenter.statusFilter?.rawValue ?? "",
                        sheetTitle: "Status",
                        onSelect: { id in presenter.statusFilter = presenter.statusOptions.first { $0.rawValue == id } }
                    )
                    if !presenter.branchOptions.isEmpty {
                        FormPickerRow(
                            label: "Cabang & Unit",
                            options: branchPickerOptions,
                            selectedId: presenter.branchFilter ?? "",
                            sheetTitle: "Cabang & Unit",
                            searchPrompt: "Cari cabang…",
                            onSelect: { id in presenter.branchFilter = id.isEmpty ? nil : id }
                        )
                    }
                    if !presenter.accountOptions.isEmpty {
                        FormPickerRow(
                            label: "Akun",
                            options: accountPickerOptions,
                            selectedId: presenter.accountFilter ?? "",
                            sheetTitle: "Akun",
                            searchPrompt: "Cari akun…",
                            showDivider: false,
                            onSelect: { id in presenter.accountFilter = id.isEmpty ? nil : id }
                        )
                    }
                }
                .padding(16)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Atur Ulang") { presenter.resetFilters() }
                        .disabled(!presenter.hasActiveFilters)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Selesai") { showFilters = false }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Helpers

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
        .frame(maxWidth: .infinity)
        // Center in the visible scroll area (75% height ≈ optical center once
        // the chip row above is accounted for).
        .containerRelativeFrame(.vertical) { length, _ in length * 0.75 }
    }
}
