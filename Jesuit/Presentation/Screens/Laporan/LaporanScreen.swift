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
        // Pinned period bar (Calendar/Health pattern) — the ledger scrolls under it.
        .safeAreaInset(edge: .top, spacing: 0) { periodBar }
        .refreshable { await presenter.load(forceReload: true) }
        .background(Color.background1.ignoresSafeArea())
        .navigationTitle("Laporan")
        .navigationBarTitleDisplayMode(.inline)
        // Tab bar is hidden by MoreScreen (the push root) while this page is up —
        // owning the modifier here would blink the bar on pop-back.
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                filterButton
                if let summary = presenter.summary {
                    exportMenu(summary)
                }
            }
        }
        .sheet(isPresented: $showFilters) { filterSheet }
        .sheet(isPresented: $showCustomRange) {
            // Shared with Home — detents applied at this call site only.
            CashFlowRangeSheet(
                initialRange: presenter.summaryRange,
                onApply: { start, end in presenter.applyCustomRange(start: start, end: end) }
            )
            .presentationDetents([.medium])
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
                .customFont(.medium, Typography.subhead)
                .foregroundStyle(.subtitle)
            Text(ReportExporter.title)
                .customFont(.semibold, Typography.title2)
                .foregroundStyle(.title)
            Text(rangeText)
                .customFont(.regular, Typography.subhead)
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

    // Ledger columns — the whole table scrolls horizontally (no frozen column).
    private let wTanggal: CGFloat = 84
    private let wNumber: CGFloat = 152
    private let wAkun: CGFloat = 124
    private let wDeskripsi: CGFloat = 168
    private let wAmount: CGFloat = 112
    private let colGap: CGFloat = 14
    /// Single font size for the whole ledger table — hierarchy comes from weight/colour.
    private let ledgerSize: CGFloat = Typography.body

    private var labelSpan: CGFloat { wTanggal + wNumber + wAkun + wDeskripsi }

    private func journalCard(_ summary: ReportSummary) -> some View {
        ScrollView(.horizontal, showsIndicators: true) {
            VStack(spacing: 0) {
                columnHeader
                Divider()
                ForEach(summary.journalEntries) { entry in
                    journalRow(entry)
                    Divider().opacity(0.35)
                }
                totalsRow(summary)
                saldoRow(summary)
            }
        }
    }

    private var columnHeader: some View {
        HStack(spacing: 0) {
            headerCell("Tanggal", width: wTanggal, align: .leading)
            headerCell("No. Transaksi", width: wNumber, align: .leading)
            headerCell("Akun", width: wAkun, align: .leading)
            headerCell("Deskripsi", width: wDeskripsi, align: .leading)
            headerCell("Debit", width: wAmount, align: .trailing)
            headerCell("Kredit", width: wAmount, align: .trailing)
        }
        .padding(.bottom, 8)
    }

    private func headerCell(_ text: String, width: CGFloat, align: Alignment) -> some View {
        Text(text)
            .font(.customFont(.semibold, ledgerSize))
            .foregroundStyle(.subtitle)
            .textCase(.uppercase)
            .lineLimit(1)
            .frame(width: width - colGap, alignment: align)
            .padding(.trailing, colGap)
    }

    private func journalRow(_ entry: JournalEntry) -> some View {
        HStack(spacing: 0) {
            textCell(dateText(entry.date), width: wTanggal, weight: .regular, color: .subtitle)
            textCell(entry.number, width: wNumber, weight: .semibold, color: .title)
            textCell(entry.account, width: wAkun, weight: .regular, color: .subtitle)
            textCell(entry.description.isEmpty ? "–" : entry.description, width: wDeskripsi, weight: .regular, color: .subtitle)
            amountCell(entry.debit, width: wAmount)
            amountCell(entry.kredit, width: wAmount)
        }
        .padding(.vertical, 14)
    }

    private func textCell(_ text: String, width: CGFloat, weight: CustomFontWeight, color: Color) -> some View {
        Text(text)
            .customFont(weight, ledgerSize)
            .foregroundStyle(color)
            .lineLimit(1)
            .monospacedDigit()
            .frame(width: width - colGap, alignment: .leading)
            .padding(.trailing, colGap)
    }

    /// One amount cell: the grouped number when non-zero, else a blank dash.
    private func amountCell(_ amount: Double, width: CGFloat, bold: Bool = false) -> some View {
        Text(amount != 0 ? amount.asGrouped : "–")
            .customFont(bold ? .bold : .regular, ledgerSize)
            .monospacedDigit()
            .foregroundStyle(amount == 0 ? Color.subtitle.opacity(0.5) : .title)
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .frame(width: width - colGap, alignment: .trailing)
            .padding(.trailing, colGap)
    }

    /// Column subtotals on a soft shaded band (the reference's "Total" row).
    private func totalsRow(_ summary: ReportSummary) -> some View {
        HStack(spacing: 0) {
            Text("Total")
                .font(.customFont(.bold, ledgerSize))
                .foregroundStyle(.title)
                .frame(width: labelSpan - colGap, alignment: .leading)
                .padding(.trailing, colGap)
            amountCell(summary.penerimaanTotal, width: wAmount, bold: true)
            amountCell(summary.pengeluaranTotal, width: wAmount, bold: true)
        }
        .padding(.vertical, 12)
        .background(Color.title.opacity(0.05))
        .padding(.top, 8)
    }

    /// The balancing figure (Debit − Kredit) on a stronger band — the grand total.
    private func saldoRow(_ summary: ReportSummary) -> some View {
        HStack(spacing: 0) {
            Text("Saldo")
                .font(.customFont(.bold, ledgerSize))
                .textCase(.uppercase)
                .foregroundStyle(.title)
                .frame(width: labelSpan - colGap, alignment: .leading)
                .padding(.trailing, colGap)
            amountCell(summary.net, width: wAmount * 2, bold: true)
        }
        .padding(.vertical, 12)
        .background(Color.title.opacity(0.09))
        .padding(.top, 4)
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

    /// Pinned bar under the nav bar: a centered tight group — prev/next steppers
    /// flanking the borderless period Menu (Fitness/Health pattern; edge-pinned
    /// steppers stacked a second chevron under the nav back button). The fixed
    /// label width keeps the steppers from jumping as the label changes. Steppers
    /// hide under a custom range — stepping is a no-op there.
    private var periodBar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 16) {
                if !presenter.hasCustomRange {
                    stepperButton(systemImage: "chevron.left") { presenter.stepPeriod(by: -1) }
                }
                periodMenu
                    .frame(minWidth: 150)
                if !presenter.hasCustomRange {
                    stepperButton(systemImage: "chevron.right") { presenter.stepPeriod(by: 1) }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            Divider().opacity(0.4)
        }
        .background(Color.background1)
        .animation(.snappy, value: presenter.hasCustomRange)
    }

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
            HStack(spacing: 6) {
                Text(presenter.steppedLabel)
                    .customFont(.semibold, Typography.headline)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.subtitle)
            }
        }
        .animation(.snappy, value: presenter.steppedLabel)
    }

    private func stepperButton(systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.subtitle)
                .frame(width: 36, height: 36)
                .background(Color.white.opacity(0.06))
                .clipShape(Circle())
        }
    }

    // MARK: - Filters

    private var filterButton: some View {
        Button { showFilters = true } label: {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .symbolVariant(presenter.hasActiveFilters ? .fill : .none)
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(.accent)
        }
    }

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
        .padding(.top, 60)
    }
}
