//
//  AssetScreen.swift
//  Jesuit
//
//  Aset (fixed assets): category chips, a combined filter sheet, a 2-column
//  photo-card grid and a floating "add asset" button. Plain CRUD list.
//  Presented as a full-screen page from Home / More rather than a bottom tab.
//

import SwiftUI

struct AssetScreen: View {
    @Injected private var session: AuthSession
    @State private var presenter = AppDI.shared.resolver(AssetPresenter.self)
    @State private var showCreate = false
    @State private var showFilter = false
    @State private var selected: SelectedAsset?

    private struct SelectedAsset: Identifiable { let id: String }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            VStack(spacing: 0) {
                ListTopBar(
                    title: "Aset",
                    searchPlaceholder: "Cari aset",
                    searchText: $presenter.searchText,
                    chips: presenter.categoryChips,
                    selectedChip: presenter.categoryLabel,
                    onSelectChip: { presenter.selectCategory(label: $0) },
                    onOpenFilter: { showFilter = true }
                )

                content
            }

            if session.can(Permission.assetCreate) {
                addButton
                    .padding(.trailing, 20)
                    .padding(.bottom, 24)
            }
        }
        .background(Color.background1.ignoresSafeArea())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .tabBar)
        .task {
            await presenter.loadCategories()
            await presenter.load()
        }
        .sheet(isPresented: $showCreate) {
            CreateAssetSheet(presenter: presenter, onCreated: {})
        }
        .sheet(item: $selected) { item in
            AssetDetailSheet(id: item.id, onChanged: { Task { await presenter.load() } })
        }
        .sheet(isPresented: $showFilter) {
            AssetFilterSheet(
                categoryOptions: presenter.categoryFilterOptions,
                statusOptions: presenter.statusFilterOptions,
                selectedCategoryId: presenter.categoryFilterId ?? "",
                selectedStatusId: presenter.statusFilter?.apiCode ?? "",
                onApply: { presenter.applyFilters(categoryId: $0, status: $1) }
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
            stateMessage("Belum ada aset.", systemImage: "tray")
        } else {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(presenter.filtered.enumerated()), id: \.element.id) { index, asset in
                        Button { selected = SelectedAsset(id: asset.id) } label: {
                            AssetCard(asset: asset)
                        }
                        .buttonStyle(.plain)
                        .onAppear {
                            if index == presenter.filtered.count - 1 {
                                Task { await presenter.loadMore() }
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 12)

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

/// One asset card in the grid: a large photo with name, value and status below.
private struct AssetCard: View {
    let asset: Asset

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // A fixed-size colour box anchors the layout; the image is overlaid
            // and clipped, so a wide photo's `scaledToFill` size can never bleed
            // into the flexible grid column and make cards uneven.
            Color.background1
                .frame(height: 130)
                .frame(maxWidth: .infinity)
                .overlay { photo }
                .clipped()

            VStack(alignment: .leading, spacing: 6) {
                Text(asset.name)
                    .customFont(.bold, Typography.callout)
                    .foregroundStyle(.title)
                    .lineLimit(2, reservesSpace: true)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text(asset.purchaseValueText)
                    .customFont(.semibold, Typography.subhead)
                    .foregroundStyle(.subtitle)
                    .lineLimit(1)

                statusPill
            }
            .padding(10)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.textFieldBG)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .contentShape(Rectangle())
    }

    private var statusPill: some View {
        Text(asset.status.rawValue)
            .customFont(.medium, Typography.caption2)
            .foregroundStyle(asset.status.tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(asset.status.tint.opacity(0.14))
            .clipShape(Capsule())
    }

    @ViewBuilder
    private var photo: some View {
        if let urlString = asset.photoUrl, let url = URL(string: urlString) {
            AsyncImage(url: url) { phase in
                switch phase {
                case .success(let image): image.resizable().scaledToFill()
                case .empty: ProgressView().tint(.accent)
                default: placeholderIcon
                }
            }
        } else {
            placeholderIcon
        }
    }

    private var placeholderIcon: some View {
        Image(systemName: "shippingbox")
            .font(.system(size: 30))
            .foregroundStyle(.subtitle)
    }
}
