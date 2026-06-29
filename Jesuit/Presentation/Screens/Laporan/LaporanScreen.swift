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
    @Environment(\.dismiss) private var dismiss
    @Injected private var session: AuthSession
    @State private var presenter = AppDI.shared.resolver(LaporanPresenter.self)
    @State private var showCustomRange = false
    @State private var showFilters = false
    @State private var activeFilter: FilterKind?
    @State private var exportItem: ExportItem?
    @State private var previewItem: ExportItem?

    /// Identifiable wrapper so `sheet(item:)` can present the share/preview by URL.
    private struct ExportItem: Identifiable { let id = UUID(); let url: URL }

    /// Which filter's selection sheet is open.
    private enum FilterKind: String, Identifiable { case status, branch, account; var id: String { rawValue } }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    filtersSection

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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.subtitle)
                }
                ToolbarItem(placement: .primaryAction) { filterButton }
                if let summary = presenter.summary {
                    ToolbarItem(placement: .primaryAction) { exportMenu(summary) }
                }
            }
            .sheet(isPresented: $showFilters) { filterSheet }
            .sheet(item: $exportItem) { item in
                ShareSheet(items: [item.url])
            }
            .fullScreenCover(item: $previewItem) { item in
                PDFPreviewSheet(url: item.url) { previewItem = nil }
                    .ignoresSafeArea()
            }
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
                // Preview first (QuickLook's share button handles the actual print/share).
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

    // MARK: - Filters

    /// Inline: just the period dropdown field. Status / Cabang & Unit / Akun live
    /// in the filter bottom sheet behind the toolbar button.
    private var filtersSection: some View {
        periodField.padding(.top, 6)  // room for the floating label
    }

    private var filterButton: some View {
        Button { showFilters = true } label: {
            Image(systemName: presenter.hasActiveFilters
                  ? "line.3.horizontal.decrease.circle.fill"
                  : "line.3.horizontal.decrease.circle")
                .foregroundStyle(.accent)
        }
    }

    /// Bottom sheet holding the Status / Cabang & Unit / Akun fields. Tapping a
    /// field opens its own selection sheet (FilterBySheet); changes apply live.
    private var filterSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    filterField("Status", value: presenter.statusLabel) { activeFilter = .status }
                    if !presenter.branchOptions.isEmpty {
                        filterField("Cabang & Unit", value: presenter.branchLabelText) { activeFilter = .branch }
                    }
                    if !presenter.accountOptions.isEmpty {
                        filterField("Akun", value: presenter.accountLabelText) { activeFilter = .account }
                    }
                }
                .padding(.top, 14)
                .padding(.horizontal, 16)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Filter")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Atur Ulang") { presenter.resetFilters() }
                        .foregroundStyle(presenter.hasActiveFilters ? .accent : .subtitle)
                        .disabled(!presenter.hasActiveFilters)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Selesai") { showFilters = false }.foregroundStyle(.accent)
                }
            }
            .sheet(item: $activeFilter) { kind in selectionSheet(kind) }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: - Filter fields

    /// A tappable outlined field (floating label + value) that opens a selection
    /// sheet — the standard selector pattern, not an inline dropdown.
    private func filterField(_ label: String, value: String,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Text(value)
                    .customFont(.semibold, Typography.body)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Image(systemName: "chevron.up.chevron.down")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.subtitle)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(fieldBackground)
            .overlay(floatingLabel(label), alignment: .topLeading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// The single-select bottom sheet for a given filter (id "" == "Semua").
    @ViewBuilder
    private func selectionSheet(_ kind: FilterKind) -> some View {
        switch kind {
        case .status:
            FilterBySheet(
                title: "Status",
                options: [FilterOption(id: "", label: "Semua Status")]
                    + presenter.statusOptions.map { FilterOption(id: $0.rawValue, label: $0.rawValue) },
                selectedId: presenter.statusFilter?.rawValue ?? "",
                onSelect: { id in presenter.statusFilter = presenter.statusOptions.first { $0.rawValue == id } }
            )
        case .branch:
            FilterBySheet(
                title: "Cabang & Unit",
                options: [FilterOption(id: "", label: "Semua Cabang & Unit")]
                    + presenter.branchOptions.map { FilterOption(id: $0.id, label: $0.name) },
                selectedId: presenter.branchFilter ?? "",
                onSelect: { id in presenter.branchFilter = id.isEmpty ? nil : id },
                searchable: true
            )
        case .account:
            FilterBySheet(
                title: "Akun",
                options: [FilterOption(id: "", label: "Semua Akun")]
                    + presenter.accountOptions.map { FilterOption(id: $0.id, label: $0.name) },
                selectedId: presenter.accountFilter ?? "",
                onSelect: { id in presenter.accountFilter = id.isEmpty ? nil : id },
                searchable: true
            )
        }
    }

    private var periodField: some View {
        Menu {
            ForEach(CashFlowPeriod.allCases) { period in
                Button {
                    presenter.cashFlowPeriod = period
                } label: {
                    if !presenter.hasCustomRange && presenter.cashFlowPeriod == period {
                        Label(period.rawValue, systemImage: "checkmark")
                    } else {
                        Text(period.rawValue)
                    }
                }
            }
            Divider()
            Button {
                showCustomRange = true
            } label: {
                if presenter.hasCustomRange {
                    Label("Rentang Khusus…", systemImage: "checkmark")
                } else {
                    Text("Rentang Khusus…")
                }
            }
        } label: {
            HStack(spacing: 8) {
                Text(presenter.steppedLabel)
                    .customFont(.semibold, Typography.body)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 4)
                Image(systemName: "calendar")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.accent)
            }
            .padding(.horizontal, 14)
            .frame(height: 52)
            .frame(maxWidth: .infinity)
            .background(fieldBackground)
            .overlay(floatingLabel("Periode"), alignment: .topLeading)
        }
        .sheet(isPresented: $showCustomRange) {
            CashFlowRangeSheet(
                initialRange: presenter.summaryRange,
                onApply: { start, end in presenter.applyCustomRange(start: start, end: end) }
            )
        }
    }

    /// A small caption that sits astride the field's top border, masking it with
    /// the screen background — the outlined-text-field look from the reference.
    private func floatingLabel(_ text: String) -> some View {
        Text(text)
            .customFont(.regular, Typography.caption2)
            .foregroundStyle(.subtitle)
            .padding(.horizontal, 4)
            .background(Color.background1)
            .offset(x: 12, y: -7)
    }

    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color.textFieldBG)
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
            )
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
