//
//  PengeluaranScreen.swift
//  Jesuit
//
//  Pengeluaran (expenses): filter chips, sortable rows and a floating
//  "add expense" button.
//

import SwiftUI

struct PengeluaranScreen: View {
    @Injected private var session: AuthSession
    @State private var presenter = AppDI.shared.resolver(PengeluaranPresenter.self)
    @State private var showCreate = false
    @State private var showFilter = false
    @State private var showSort = false
    @State private var selected: SelectedExpense?

    /// Identifiable wrapper so `sheet(item:)` can present an expense by id.
    private struct SelectedExpense: Identifiable { let id: String }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                ListTopBar(
                    title: "Pengeluaran",
                    searchPlaceholder: "Cari pengeluaran",
                    searchText: $presenter.searchText,
                    chips: PengeluaranPresenter.Filter.quickChips.map(\.rawValue),
                    selectedChip: presenter.filter.rawValue,
                    onSelectChip: { label in
                        if let f = PengeluaranPresenter.Filter(rawValue: label) { presenter.filter = f }
                    },
                    onOpenFilter: { showFilter = true },
                    onOpenSort: { showSort = true }
                )

                content
            }

            if session.can(Permission.cashCreate) {
                addButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
            }
        }
        .background(Color.background1.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await presenter.load() }
        .sheet(isPresented: $showCreate) {
            CreateExpenseSheet(presenter: presenter, onCreated: {})
        }
        .sheet(item: $selected) { item in
            CashReceiptDetailSheet(id: item.id, kind: .disbursement,
                                   onChanged: { Task { await presenter.load() } })
        }
        .sheet(isPresented: $showFilter) {
            FilterBySheet(
                title: "Filter Berdasarkan",
                options: PengeluaranPresenter.Filter.allCases.map {
                    FilterOption(id: $0.rawValue, label: $0.rawValue, count: presenter.count(for: $0.status))
                },
                selectedId: presenter.filter.rawValue,
                onSelect: { id in
                    if let f = PengeluaranPresenter.Filter(rawValue: id) { presenter.filter = f }
                }
            )
        }
        .sheet(isPresented: $showSort) {
            SortBySheet(
                field: presenter.sortField,
                direction: presenter.sortDirection,
                onApply: { field, direction in
                    presenter.sortField = field
                    presenter.sortDirection = direction
                }
            )
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
            stateMessage("Belum ada pengeluaran kas.", systemImage: "receipt")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(presenter.filtered.enumerated()), id: \.element.id) { index, expense in
                        Button { selected = SelectedExpense(id: expense.id) } label: {
                            CashReceiptRow(receipt: expense)
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
