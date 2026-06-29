//
//  ApprovalInboxScreen.swift
//  Jesuit
//
//  Approval Inbox: every penerimaan/pengeluaran still waiting for approval, in
//  one list. Tapping a row opens the shared detail sheet, which already hosts
//  the permission-gated Setujui/Tolak actions. Presented as a sheet from More.
//

import SwiftUI

struct ApprovalInboxScreen: View {
    @Injected private var navigation: NavigationService
    @State private var presenter = AppDI.shared.resolver(ApprovalInboxPresenter.self)
    @State private var selected: ApprovalInboxPresenter.InboxItem?

    var body: some View {
        // Pushed as a top-level UIPilot route (sibling of MainTabScreen), so it owns
        // its OWN NavigationStack and stays outside the TabView — which is what stops
        // the tab bar blinking on pop.
        NavigationStack {
            content
                .background(Color.background1.ignoresSafeArea())
                .navigationTitle("Persetujuan")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button { navigation.pop() } label: {
                            Image(systemName: "chevron.backward")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(.title)
                        }
                    }
                }
                .task { await presenter.load() }
                .navigationDestination(item: $selected) { item in
                    CashReceiptDetailSheet(id: item.id, kind: item.kind,
                                           onChanged: { Task { await presenter.load() } })
                }
        }
        .hotReloadable()
    }

    @ViewBuilder
    private var content: some View {
        if presenter.isLoading {
            ProgressView().tint(.accent)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = presenter.errorMessage {
            stateMessage(error, systemImage: "exclamationmark.triangle")
        } else if presenter.items.isEmpty {
            stateMessage("Tidak ada transaksi menunggu persetujuan.", systemImage: "checkmark.seal")
        } else {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(presenter.items.enumerated()), id: \.element.id) { index, item in
                        Button { selected = item } label: {
                            CashReceiptRow(receipt: item.receipt)
                                .padding(.horizontal, ListMetrics.horizontalInset)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        RowDivider(index: index, count: presenter.items.count)
                    }
                }
                .padding(.top, 4)
            }
            .refreshable { await presenter.load() }
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
