//
//  ArusKasScreen.swift
//  Jesuit
//
//  Arus Kas (cash flow statement) for the selected period: opening balance,
//  inflows, outflows, net movement and closing balance — plus a per-account
//  breakdown table. Pushed from LaporanIndexScreen.
//

import SwiftUI

struct ArusKasScreen: View {
    @Injected private var session: AuthSession
    @State private var presenter = AppDI.shared.resolver(ArusKasPresenter.self)
    @State private var showCustomRange = false

    private let colGap: CGFloat = 14

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                PeriodMenuChip(period: presenter.period, showCustomRange: $showCustomRange)
                if presenter.isLoading {
                    ProgressView().tint(.accent)
                        .frame(maxWidth: .infinity, minHeight: 200)
                } else if let error = presenter.errorMessage {
                    ReportStateMessage(text: error, systemImage: "exclamationmark.triangle")
                } else if let statement = presenter.statement {
                    ReportHeader(
                        organization: session.organization,
                        title: "Laporan Arus Kas",
                        subtitle: reportRangeText(presenter.period.range)
                    )
                    statementCard(statement)
                    accountsCard(statement)
                } else {
                    ReportStateMessage(text: "Tidak ada transaksi pada periode ini.", systemImage: "tray")
                }
            }
            .padding(16)
        }
        .refreshable { await presenter.load(forceReload: true) }
        .background(Color.background1.ignoresSafeArea())
        .navigationTitle("Arus Kas")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCustomRange) {
            CashFlowRangeSheet(
                initialRange: presenter.period.range,
                onApply: { start, end in presenter.period.applyCustomRange(start: start, end: end) }
            )
        }
        .task { await presenter.load() }
        .hotReloadable()
    }

    // MARK: - Statement

    private func statementCard(_ statement: CashFlowStatement) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 0) {
                line("Saldo Awal Kas", statement.opening)
                Divider()
                line("Penerimaan Kas", statement.inflow)
                Divider()
                line("Pengeluaran Kas", -statement.outflow)
                Divider()
                line("Kenaikan (Penurunan) Kas", statement.net, weight: .semibold)

                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("Saldo Akhir Kas")
                        .customFont(.bold, Typography.body)
                        .foregroundStyle(.title)
                    Spacer(minLength: 8)
                    Text(statement.closing.asAccounting)
                        .customFont(.bold, Typography.body)
                        .foregroundStyle(.title)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 12)
                .background(Color.title.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                .padding(.top, 8)
            }
        }
    }

    private func line(_ label: String, _ amount: Double, weight: CustomFontWeight = .regular) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .customFont(weight, Typography.body)
                .foregroundStyle(.title)
            Spacer(minLength: 8)
            Text(amount.asAccounting)
                .customFont(weight, Typography.body)
                .foregroundStyle(.title)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .padding(.vertical, 10)
    }

    // MARK: - Per-account breakdown

    private func accountsCard(_ statement: CashFlowStatement) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Per Akun Kas")
                .customFont(.semibold, Typography.headline)
                .foregroundStyle(.title)
            ScrollView(.horizontal, showsIndicators: true) {
                Grid(alignment: .leading, horizontalSpacing: 0, verticalSpacing: 0) {
                    GridRow {
                        headerCell("Akun")
                        headerCell("Saldo Awal", align: .trailing)
                        headerCell("Masuk", align: .trailing)
                        headerCell("Keluar", align: .trailing)
                        headerCell("Saldo Akhir", align: .trailing)
                    }
                    Divider()
                    ForEach(statement.perAccount) { account in
                        GridRow {
                            metaCell(account.name)
                            amountCell(account.opening, dashWhenZero: false)
                            amountCell(account.inflow)
                            amountCell(account.outflow)
                            amountCell(account.closing, dashWhenZero: false)
                        }
                        Divider().opacity(0.35)
                    }
                }
            }
        }
    }

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

    private func metaCell(_ text: String) -> some View {
        Text(text)
            .customFont(.regular, ListMetrics.metaSize)
            .foregroundStyle(.subtitle)
            .lineLimit(1)
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
}
