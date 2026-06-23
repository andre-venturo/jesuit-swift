//
//  LaporanScreen.swift
//  Jesuit
//
//  Laporan (report): pick a period and see total penerimaan, total pengeluaran,
//  net, transaction counts and a per-account breakdown — all computed from the
//  cash-transactions records via LaporanPresenter.
//

import SwiftUI

struct LaporanScreen: View {
    @Environment(\.dismiss) private var dismiss
    @State private var presenter = AppDI.shared.resolver(LaporanPresenter.self)
    @State private var showCustomRange = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    periodSelector

                    if presenter.isLoading {
                        ProgressView().tint(.accent)
                            .frame(maxWidth: .infinity, minHeight: 200)
                    } else if let error = presenter.errorMessage {
                        stateMessage(error, systemImage: "exclamationmark.triangle")
                    } else if let summary = presenter.summary {
                        content(summary)
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
            }
        }
        .task { await presenter.load() }
        .hotReloadable()
    }

    // MARK: - Content

    @ViewBuilder
    private func content(_ summary: ReportSummary) -> some View {
        summaryCards(summary)

        breakdownCard(
            title: "Penerimaan per Akun",
            total: summary.penerimaanTotal,
            tint: .income,
            breakdown: summary.penerimaanByAccount
        )

        breakdownCard(
            title: "Pengeluaran per Akun",
            total: summary.pengeluaranTotal,
            tint: .expense,
            breakdown: summary.pengeluaranByAccount
        )
    }

    private func summaryCards(_ summary: ReportSummary) -> some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                metricCard(
                    "Penerimaan", summary.penerimaanTotal, summary.penerimaanCount,
                    tint: .income, systemImage: "arrow.down.circle.fill"
                )
                metricCard(
                    "Pengeluaran", summary.pengeluaranTotal, summary.pengeluaranCount,
                    tint: .expense, systemImage: "arrow.up.circle.fill"
                )
            }
            netCard(summary.net)
        }
    }

    private func metricCard(
        _ title: String, _ amount: Double, _ count: Int,
        tint: Color, systemImage: String
    ) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 18))
                    .foregroundStyle(tint)
                Text(amount.asRupiah)
                    .customFont(.bold, Typography.headline)
                    .foregroundStyle(.title)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                Text("\(title) · \(count) transaksi")
                    .customFont(.regular, Typography.subhead)
                    .foregroundStyle(.subtitle)
                    .lineLimit(1)
            }
        }
    }

    private func netCard(_ net: Double) -> some View {
        CardContainer {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Selisih (Net)")
                        .customFont(.regular, Typography.subhead)
                        .foregroundStyle(.subtitle)
                    Text(net.asSignedRupiah)
                        .customFont(.bold, Typography.title2)
                        .foregroundStyle(net >= 0 ? Color.income : Color.expense)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: net >= 0 ? "arrow.up.right" : "arrow.down.right")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(net >= 0 ? Color.income : Color.expense)
            }
        }
    }

    // MARK: - Breakdown card (proportion bar + per-account list)

    @ViewBuilder
    private func breakdownCard(
        title: String, total: Double, tint: Color, breakdown: [ExpenseBreakdown]
    ) -> some View {
        CardContainer {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(title)
                        .customFont(.semibold, Typography.headline)
                        .foregroundStyle(.title)
                    Spacer()
                    Text(total.asRupiah)
                        .customFont(.bold, Typography.headline)
                        .foregroundStyle(tint)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }

                if breakdown.isEmpty {
                    Text("Tidak ada data pada periode ini.")
                        .customFont(.regular, Typography.body)
                        .foregroundStyle(.subtitle)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    proportionBar(breakdown, total: total)
                    breakdownList(breakdown, total: total)
                }
            }
        }
    }

    private func proportionBar(_ breakdown: [ExpenseBreakdown], total: Double) -> some View {
        GeometryReader { geo in
            HStack(spacing: 2) {
                ForEach(breakdown) { item in
                    color(for: item.color)
                        .frame(width: max(4, geo.size.width * share(item, total)))
                }
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
    }

    private func breakdownList(_ breakdown: [ExpenseBreakdown], total: Double) -> some View {
        VStack(spacing: 14) {
            ForEach(breakdown) { item in
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color(for: item.color))
                        .frame(width: 14, height: 14)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.category)
                            .customFont(.medium, Typography.body)
                            .foregroundStyle(.title)
                            .lineLimit(1)
                        Text(percentLabel(item, total))
                            .customFont(.regular, Typography.subhead)
                            .foregroundStyle(.subtitle)
                    }
                    Spacer()
                    Text(item.amount.asRupiah)
                        .customFont(.semibold, Typography.callout)
                        .foregroundStyle(.title)
                        .lineLimit(1)
                }
            }
        }
    }

    // MARK: - Period selector

    private var periodSelector: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Periode")
                    .customFont(.semibold, Typography.headline)
                    .foregroundStyle(.title)
                Spacer()
                periodMenu
            }
            if presenter.hasCustomRange {
                Text(presenter.steppedLabel)
                    .customFont(.semibold, Typography.headline)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            } else {
                periodStepper
            }
        }
    }

    private var periodStepper: some View {
        HStack {
            stepperButton(systemImage: "chevron.left") { presenter.stepPeriod(by: -1) }
            Spacer()
            Text(presenter.steppedLabel)
                .customFont(.semibold, Typography.headline)
                .foregroundStyle(.title)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            stepperButton(systemImage: "chevron.right") { presenter.stepPeriod(by: 1) }
        }
        .padding(.horizontal, 4)
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

    private var periodMenu: some View {
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
            HStack(spacing: 6) {
                Text(presenter.rangeLabel)
                    .customFont(.medium, Typography.body)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.subtitle)
            }
        }
        .sheet(isPresented: $showCustomRange) {
            CashFlowRangeSheet(
                initialRange: presenter.summaryRange,
                onApply: { start, end in presenter.applyCustomRange(start: start, end: end) }
            )
        }
    }

    // MARK: - Helpers

    private func share(_ item: ExpenseBreakdown, _ total: Double) -> Double {
        total > 0 ? item.amount / total : 0
    }

    private func percentLabel(_ item: ExpenseBreakdown, _ total: Double) -> String {
        let pct = share(item, total) * 100
        return String(format: "%.1f%%", pct).replacingOccurrences(of: ".", with: ",")
    }

    private func color(for c: ExpenseBreakdownColor) -> Color {
        switch c {
        case .blue:   return Color(red: 0.30, green: 0.56, blue: 1.0)
        case .teal:   return Color(red: 0.20, green: 0.75, blue: 0.70)
        case .orange: return .orange
        case .purple: return Color(red: 0.58, green: 0.44, blue: 0.86)
        case .pink:   return Color(red: 0.92, green: 0.45, blue: 0.62)
        case .gray:   return Color.gray
        }
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
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }
}
