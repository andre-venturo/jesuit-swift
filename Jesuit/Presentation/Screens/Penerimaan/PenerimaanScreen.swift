//
//  PenerimaanScreen.swift
//  Jesuit
//
//  Penerimaan Kas (cash receipts): filter chips, sortable rows and a floating
//  "add receipt" button.
//

import SwiftUI

struct PenerimaanScreen: View {
    @State private var presenter = AppDI.shared.resolver(PenerimaanPresenter.self)
    @State private var showCreate = false
    @State private var selected: SelectedReceipt?

    /// Identifiable wrapper so `sheet(item:)` can present a receipt by id.
    private struct SelectedReceipt: Identifiable { let id: String }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                ListTopBar(
                    title: "Penerimaan",
                    searchPlaceholder: "Cari penerimaan",
                    searchText: $presenter.searchText,
                    chips: PenerimaanPresenter.Filter.allCases.map(\.rawValue),
                    selectedChip: presenter.filter.rawValue,
                    onSelectChip: { label in
                        if let f = PenerimaanPresenter.Filter(rawValue: label) { presenter.filter = f }
                    },
                    onToggleSort: { presenter.toggleSort() }
                )

                content
            }

            addButton
                .padding(.trailing, 20)
                .padding(.bottom, 24)
        }
        .background(Color.background1.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await presenter.load() }
        .sheet(isPresented: $showCreate) {
            CreateReceiptSheet(presenter: presenter, onCreated: {})
        }
        .sheet(item: $selected) { item in
            CashReceiptDetailSheet(id: item.id, onChanged: { Task { await presenter.load() } })
        }
        .hotReloadable()
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if presenter.isLoading {
            Spacer()
            ProgressView().tint(.accent)
            Spacer()
        } else if let error = presenter.errorMessage {
            stateMessage(error, systemImage: "exclamationmark.triangle")
        } else if presenter.filtered.isEmpty {
            stateMessage("Belum ada penerimaan kas.", systemImage: "tray")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(presenter.filtered.enumerated()), id: \.element.id) { index, receipt in
                        Button { selected = SelectedReceipt(id: receipt.id) } label: {
                            CashReceiptRow(receipt: receipt)
                                .padding(.horizontal, ListMetrics.horizontalInset)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        RowDivider(index: index, count: presenter.filtered.count)
                    }
                }
                .padding(.top, 4)
            }
            .refreshable { await presenter.load() }
        }
    }

    // MARK: - Floating add button

    private var addButton: some View {
        Button {
            showCreate = true
        } label: {
            Image(systemName: "plus")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.accentColor)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
        }
    }

    @ViewBuilder
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }
}
