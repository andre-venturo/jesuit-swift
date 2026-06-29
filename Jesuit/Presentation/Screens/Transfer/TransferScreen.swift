//
//  TransferScreen.swift
//  Jesuit
//
//  Transfer Dana (fund transfers): filter chips, transfer rows and a floating
//  "add transfer" button. Mirrors the Penerimaan list. Presented as a full-screen
//  page from Home / More rather than a bottom tab.
//

import SwiftUI

struct TransferScreen: View {
    @Injected private var session: AuthSession
    @State private var presenter = AppDI.shared.resolver(TransferPresenter.self)
    @State private var showCreate = false
    @State private var showFilter = false
    @State private var showPeriod = false
    @State private var showCustomRange = false
    @State private var selected: SelectedTransfer?

    private struct SelectedTransfer: Identifiable, Hashable { let id: String }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                ListTopBar(
                    title: "Transfer Dana",
                    searchPlaceholder: "Cari transfer",
                    searchText: $presenter.searchText,
                    chips: TransferPresenter.Filter.quickChips.map(\.rawValue),
                    selectedChip: presenter.filter.rawValue,
                    onSelectChip: { label in
                        if let f = TransferPresenter.Filter(rawValue: label) { presenter.filter = f }
                    },
                    onOpenFilter: { showFilter = true },
                    onOpenPeriod: { showPeriod = true },
                    periodActive: presenter.periodFrom != nil
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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task { await presenter.load() }
        .task { await presenter.loadAccounts() }
        .sheet(isPresented: $showCreate) {
            CreateTransferSheet(presenter: presenter, onCreated: {})
        }
        .navigationDestination(item: $selected) { item in
            TransferDetailSheet(id: item.id, onChanged: { Task { await presenter.load() } })
        }
        .sheet(isPresented: $showFilter) {
            FilterBySheet(
                title: "Filter Berdasarkan",
                options: TransferPresenter.Filter.allCases.map {
                    FilterOption(id: $0.rawValue, label: $0.rawValue, count: presenter.count(for: $0.status))
                },
                selectedId: presenter.filter.rawValue,
                onSelect: { id in
                    if let f = TransferPresenter.Filter(rawValue: id) { presenter.filter = f }
                }
            )
        }
        .sheet(isPresented: $showPeriod) {
            FilterBySheet(
                title: "Periode",
                options: periodOptions,
                selectedId: presenter.periodId,
                onSelect: { id in
                    switch id {
                    case "": presenter.clearPeriod()
                    case "custom": showCustomRange = true
                    default:
                        if let p = CashFlowPeriod(rawValue: id) { presenter.selectPeriod(p) }
                    }
                }
            )
        }
        .sheet(isPresented: $showCustomRange) {
            CashFlowRangeSheet(
                initialRange: (presenter.periodFrom ?? .now, presenter.periodTo ?? .now),
                onApply: { start, end in presenter.applyCustomPeriod(start: start, end: end) }
            )
        }
        .hotReloadable()
    }

    private var periodOptions: [FilterOption] {
        [FilterOption(id: "", label: "Semua Periode")]
            + CashFlowPeriod.allCases.map { FilterOption(id: $0.rawValue, label: $0.rawValue) }
            + [FilterOption(id: "custom", label: "Rentang Khusus…")]
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
            stateMessage("Belum ada transfer dana.", systemImage: "tray")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(presenter.filtered.enumerated()), id: \.element.id) { index, transfer in
                        Button { selected = SelectedTransfer(id: transfer.id) } label: {
                            TransferRow(
                                transfer: transfer,
                                fromName: presenter.accountName(for: transfer.fromAccountId),
                                toName: presenter.accountName(for: transfer.toAccountId)
                            )
                            .padding(.horizontal, ListMetrics.horizontalInset)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if index == presenter.filtered.count - 1 {
                                Task { await presenter.loadMore() }
                            }
                        }
                        RowDivider(index: index, count: presenter.filtered.count)
                    }
                    if presenter.isLoadingMore {
                        ProgressView().tint(.accent)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    } else if presenter.loadMoreFailed {
                        Button { Task { await presenter.loadMore() } } label: {
                            Text("Gagal memuat. Ketuk untuk coba lagi.")
                                .customFont(.medium, Typography.callout)
                                .foregroundStyle(.expense)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        }
                    }
                }
                .padding(.top, 4)
            }
            .refreshable { await presenter.load() }
        }
    }

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

/// One fund-transfer row: title + amount, a date • number subtitle and status.
private struct TransferRow: View {
    let transfer: FundTransfer
    let fromName: String
    let toName: String

    private var title: String {
        transfer.description.isEmpty ? "Transfer Dana" : transfer.description
    }

    private var dateLabel: String {
        let f = DateFormatter()
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: transfer.date)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ListMetrics.rowLineSpacing) {
            HStack(alignment: .firstTextBaseline) {
                Text(title)
                    .customFont(.bold, ListMetrics.titleSize)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                Spacer(minLength: 12)
                Text(transfer.amountText)
                    .customFont(.bold, ListMetrics.titleSize)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
            }

            if !fromName.isEmpty || !toName.isEmpty {
                HStack(spacing: 6) {
                    if !fromName.isEmpty {
                        Text(fromName)
                            .customFont(.medium, ListMetrics.metaSize)
                            .foregroundStyle(.title)
                            .lineLimit(1)
                    }
                    Image(systemName: "arrow.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.accent)
                    if !toName.isEmpty {
                        Text(toName)
                            .customFont(.medium, ListMetrics.metaSize)
                            .foregroundStyle(.title)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
            }

            HStack(spacing: 8) {
                Text(dateLabel)
                    .customFont(.regular, ListMetrics.metaSize)
                    .foregroundStyle(.subtitle)
                Circle().fill(Color.subtitle).frame(width: 4, height: 4)
                Text(transfer.number)
                    .customFont(.regular, ListMetrics.metaSize)
                    .foregroundStyle(.subtitle)
            }

            HStack {
                Text(transfer.status.rawValue.uppercased())
                    .customFont(.medium, ListMetrics.statusSize)
                    .foregroundStyle(transfer.status.tint)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.subtitle)
            }
        }
        .padding(.vertical, ListMetrics.rowVerticalPadding)
    }
}
