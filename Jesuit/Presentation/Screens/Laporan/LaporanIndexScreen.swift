//
//  LaporanIndexScreen.swift
//  Jesuit
//
//  Report catalog pushed from More → Laporan: one row per report type.
//  Only Jurnal Umum (LaporanScreen) exists today; the rest are listed as
//  "Segera" placeholders so the menu already shows the full lineup.
//

import SwiftUI

struct LaporanIndexScreen: View {
    @State private var showJurnalUmum = false
    @State private var showNeraca = false

    private struct Report: Identifiable {
        let icon: String
        let title: String
        var action: (() -> Void)?
        var id: String { title }
    }

    private var reports: [Report] {
        [
            Report(icon: "doc.plaintext", title: "Jurnal Umum") { showJurnalUmum = true },
            Report(icon: "scalemass", title: "Neraca") { showNeraca = true },
            Report(icon: "books.vertical", title: "Buku Besar"),
            Report(icon: "chart.line.uptrend.xyaxis", title: "Laba Rugi"),
            Report(icon: "building.columns", title: "Arus Kas"),
        ]
    }

    var body: some View {
        ScrollView {
            ListCard {
                ForEach(Array(reports.enumerated()), id: \.element.id) { index, report in
                    Button {
                        report.action?()
                    } label: {
                        MoreRow(icon: report.icon, title: report.title,
                                value: report.action == nil ? "Segera" : "")
                            .opacity(report.action == nil ? 0.45 : 1)
                    }
                    .buttonStyle(.plain)
                    .disabled(report.action == nil)
                    RowDivider(index: index, count: reports.count, inset: 52)
                }
            }
            .padding(16)
        }
        .background(Color.background1.ignoresSafeArea())
        .navigationTitle("Laporan")
        .navigationBarTitleDisplayMode(.inline)
        // Tab bar stays hidden via MoreScreen's push flag through nested pushes.
        .navigationDestination(isPresented: $showJurnalUmum) {
            LaporanScreen()
        }
        // Neraca owns its NavigationStack + Tutup (built for Home's sheet) —
        // present it the same way here rather than pushing a nested stack.
        .sheet(isPresented: $showNeraca) {
            NeracaScreen()
        }
        .hotReloadable()
    }
}
