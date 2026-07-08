//
//  MasterAkunScreen.swift
//  Jesuit
//
//  Master Akun (chart of accounts): type chips, a status filter sheet, a
//  type-sectioned account list and a floating "add account" button. Full CRUD
//  master data. Presented as a full-screen page from More rather than a tab.
//

import SwiftUI

struct MasterAkunScreen: View {
    @Injected private var navigation: NavigationService
    @Injected private var session: AuthSession
    @State private var presenter = AppDI.shared.resolver(MasterAkunPresenter.self)
    @State private var showCreate = false
    @State private var showFilter = false
    @State private var showSearch = false
    /// Non-nil pushes the edit form for this account (Kontak pattern — master
    /// data goes straight to edit, no read-only detail page in between).
    @State private var editingAccount: ChartAccount?

    var body: some View {
        // Pushed as a top-level UIPilot route (sibling of MainTabScreen), so this owns
        // its OWN NavigationStack for the title + detail pushes; UIPilot keeps its bar
        // hidden. Being outside the TabView is what stops the tab bar blinking on pop.
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                VStack(spacing: 0) {
                    ListTopBar(
                        title: "Master Akun",
                        searchPlaceholder: "Cari nama atau kode akun",
                        searchText: $presenter.searchText,
                        chips: ["Semua"] + AccountType.allCases.map(\.label),
                        selectedChip: presenter.typeFilter?.label ?? "Semua",
                        onSelectChip: { label in
                            presenter.typeFilter = AccountType.allCases.first { $0.label == label }
                        },
                        onOpenFilter: { showFilter = true },
                        showTitle: false,
                        showSearchButton: false,
                        externalShowSearch: $showSearch
                    )

                    content
                }

                if session.can(Permission.accountCreate) {
                    addButton
                        .padding(.trailing, 20)
                        .padding(.bottom, 24)
                }
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Master Akun")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { navigation.pop() } label: {
                        Image(systemName: "chevron.backward")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.title)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { withAnimation { showSearch.toggle() } } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.title)
                    }
                }
            }
            .task { await presenter.load() }
            .navigationDestination(isPresented: $showCreate) {
                CreateAccountSheet(presenter: presenter, onSaved: {})
            }
            .navigationDestination(item: $editingAccount) { account in
                CreateAccountSheet(presenter: presenter, editing: account, onSaved: {})
            }
            .sheet(isPresented: $showFilter) {
                FilterBySheet(
                    title: "Status",
                    options: MasterAkunPresenter.StatusFilter.allCases.map {
                        FilterOption(id: $0.rawValue, label: $0.rawValue)
                    },
                    selectedId: presenter.statusFilter.rawValue,
                    onSelect: { id in
                        if let f = MasterAkunPresenter.StatusFilter(rawValue: id) {
                            presenter.statusFilter = f
                        }
                    }
                )
            }
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
            stateMessage("Belum ada akun.", systemImage: "tray")
        } else {
            ScrollView {
                LazyVStack(spacing: 0, pinnedViews: []) {
                    ForEach(presenter.sections, id: \.type) { section in
                        sectionHeader(section.type?.label ?? "Lainnya")
                        ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, account in
                            Button { editingAccount = account } label: {
                                AccountRow(account: account)
                            }
                            .buttonStyle(.plain)
                            RowDivider(index: index, count: section.rows.count,
                                       inset: ListMetrics.horizontalInset)
                        }
                    }
                }
                .padding(.bottom, 96)  // clear the floating add button
            }
            .refreshable { await presenter.load() }
        }
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text.uppercased())
            .customFont(.semibold, Typography.caption)
            .foregroundStyle(.subtitle)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ListMetrics.horizontalInset)
            .padding(.top, 20)
            .padding(.bottom, 8)
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

/// One account row: code + name on the left, balance and status on the right.
private struct AccountRow: View {
    let account: ChartAccount

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(account.name)
                    .customFont(.semibold, ListMetrics.titleSize)
                    .foregroundStyle(.title)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    if let code = account.code, !code.isEmpty {
                        Text(code)
                            .customFont(.regular, ListMetrics.metaSize)
                            .foregroundStyle(.subtitle)
                            .monospacedDigit()
                    }
                    if account.isHeader {
                        pill("Induk", tint: .subtitle)
                    }
                    if !account.isActive {
                        pill("Nonaktif", tint: .expense)
                    }
                }
            }
            Spacer(minLength: 12)
            Text(account.balance?.asRupiah ?? "—")
                .customFont(.medium, ListMetrics.titleSize)
                .foregroundStyle(account.balance == nil ? .subtitle : .title)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, ListMetrics.horizontalInset)
        .padding(.vertical, ListMetrics.rowVerticalPadding)
        .contentShape(Rectangle())
    }

    private func pill(_ text: String, tint: Color) -> some View {
        Text(text)
            .customFont(.medium, ListMetrics.statusSize)
            .foregroundStyle(tint)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(tint.opacity(0.14))
            .clipShape(Capsule())
    }
}
