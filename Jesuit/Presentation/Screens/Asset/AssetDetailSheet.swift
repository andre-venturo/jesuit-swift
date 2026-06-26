//
//  AssetDetailSheet.swift
//  Jesuit
//
//  Aset detail: photos, asset info (category/branch/location/quantity), purchase
//  details, depreciation, note, and the permission-gated actions (Ubah / Hapus).
//  Plain CRUD — no approval workflow.
//

import SwiftUI

struct AssetDetailSheet: View {
    let id: String
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var presenter: AssetDetailPresenter
    @State private var showEdit = false
    @State private var showDeleteConfirm = false
    @State private var previewImage: PreviewImage?
    @State private var actionError: String?
    @State private var showDepreciation = false

    init(id: String, onChanged: @escaping () -> Void) {
        self.id = id
        self.onChanged = onChanged
        _presenter = State(initialValue: AppDI.shared.assetDetailPresenter(id: id))
    }

    var body: some View {
        NavigationStack {
            Group {
                if presenter.isLoading {
                    ProgressView().tint(.accent)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = presenter.errorMessage {
                    stateMessage(error, systemImage: "exclamationmark.triangle")
                } else if let detail = presenter.detail {
                    content(detail)
                } else {
                    stateMessage("Detail tidak tersedia.", systemImage: "doc")
                }
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle(presenter.detail?.code ?? "Detail")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.subtitle)
                }
            }
        }
        .task { await presenter.load() }
        .sheet(isPresented: $showEdit) {
            if let detail = presenter.detail {
                CreateAssetSheet(editing: detail, onCreated: {
                    onChanged()
                    Task { await presenter.load() }
                })
            }
        }
        .fullScreenCover(item: $previewImage) { ImagePreviewSheet(image: $0) }
        .alert("Hapus aset?", isPresented: $showDeleteConfirm) {
            Button("Batal", role: .cancel) {}
            Button("Hapus", role: .destructive) {
                Task {
                    if await presenter.delete() {
                        onChanged()
                        dismiss()
                    } else {
                        actionError = presenter.actionErrorMessage
                    }
                }
            }
        } message: {
            Text("Tindakan ini tidak dapat dibatalkan.")
        }
        .alert("Gagal", isPresented: Binding(get: { actionError != nil }, set: { if !$0 { actionError = nil } })) {
            Button("OK", role: .cancel) { actionError = nil }
        } message: {
            Text(actionError ?? "")
        }
    }

    // MARK: - Content

    private func content(_ detail: AssetDetail) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                hero(detail)
                if !presenter.photos.isEmpty { photosCard }
                infoCard(detail)
                purchaseCard(detail)
                depreciationCard(detail)
                if !detail.note.isEmpty { notesCard(detail.note) }
            }
            .padding(20)
            .padding(.bottom, 90)
        }
        .safeAreaInset(edge: .bottom) { actionBar }
        .overlay {
            if presenter.isWorking {
                Color.black.opacity(0.2).ignoresSafeArea()
                ProgressView().tint(.accent)
            }
        }
    }

    // MARK: - Hero

    private func hero(_ detail: AssetDetail) -> some View {
        VStack(spacing: 8) {
            Text(detail.name)
                .customFont(.bold, Typography.title)
                .foregroundStyle(.title)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            Text(detail.purchaseValue.asRupiah)
                .customFont(.bold, Typography.title2)
                .foregroundStyle(.subtitle)
            statusPill(detail).padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }

    private func statusPill(_ detail: AssetDetail) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(detail.status.rawValue)
                .customFont(.semibold, Typography.subhead)
        }
        .foregroundStyle(detail.status.tint)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(detail.status.tint.opacity(0.14))
        .clipShape(Capsule())
    }

    // MARK: - Photos

    private var photosCard: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(presenter.photos) { photo in
                    photoThumbnail(photo)
                }
            }
        }
    }

    @ViewBuilder
    private func photoThumbnail(_ photo: CashLineAttachment) -> some View {
        let size: CGFloat = 110
        Button {
            if let preview = PreviewImage(photo) { previewImage = preview }
        } label: {
            Group {
                if photo.isImage, let url = URL(string: photo.fileUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image): image.resizable().scaledToFill()
                        case .empty: ProgressView().tint(.accent)
                        default: placeholderTile
                        }
                    }
                } else {
                    placeholderTile
                }
            }
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var placeholderTile: some View {
        ZStack {
            Color.textFieldBG
            Image(systemName: "doc").font(.system(size: 24)).foregroundStyle(.subtitle)
        }
    }

    // MARK: - Cards

    private func infoCard(_ detail: AssetDetail) -> some View {
        var pairs: [(String, String)] = [
            ("Kode Aset", detail.code),
            ("Kategori", detail.categoryName),
            ("Cabang", detail.branchName)
        ]
        if !detail.location.isEmpty { pairs.append(("Lokasi", detail.location)) }
        pairs.append(("Jumlah", String(detail.quantity)))
        return rowsCard(title: nil, pairs: pairs)
    }

    private func purchaseCard(_ detail: AssetDetail) -> some View {
        var pairs: [(String, String)] = [
            ("Nilai Pembelian", detail.purchaseValue.asRupiah)
        ]
        if let date = detail.purchaseDate { pairs.append(("Tanggal Pembelian", Self.dayFormat(date))) }
        if let date = detail.startUseDate { pairs.append(("Tanggal Pakai", Self.dayFormat(date))) }
        let age = assetAge(detail)
        if age != "—" { pairs.append(("Umur Aset", age)) }
        if detail.isIntangible { pairs.append(("Tak Berwujud", "Ya")) }
        return rowsCard(title: "Pembelian", pairs: pairs)
    }

    /// Read-only depreciation, collapsed behind a disclosure to keep the common
    /// info short — most users never edit these on mobile.
    private func depreciationCard(_ detail: AssetDetail) -> some View {
        var pairs: [(String, String)] = [
            ("Metode", Self.depreciationLabel(detail.depreciationMethod)),
            ("Nilai Residu", detail.salvageValue.asRupiah)
        ]
        if detail.depreciationMethod == "declining-balance" {
            pairs.append(("Tarif Penyusutan", "\(Int(detail.depreciationRate ?? 0))%"))
        }
        return VStack(spacing: 0) {
            Button { withAnimation(.easeInOut) { showDepreciation.toggle() } } label: {
                HStack {
                    Text("Penyusutan")
                        .customFont(.semibold, Typography.callout)
                        .foregroundStyle(.title)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.subtitle)
                        .rotationEffect(.degrees(showDepreciation ? 180 : 0))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showDepreciation {
                ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                    cardDivider
                    infoRow(pair.0, pair.1)
                }
            }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    /// A grouped card from `(label, value)` pairs, drawing inset dividers between
    /// rows and an optional uppercased section header.
    private func rowsCard(title: String?, pairs: [(String, String)]) -> some View {
        VStack(spacing: 0) {
            if let title { sectionHeader(title) }
            ForEach(Array(pairs.enumerated()), id: \.offset) { index, pair in
                if index > 0 { cardDivider }
                infoRow(pair.0, pair.1)
            }
        }
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func notesCard(_ text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Catatan")
                .customFont(.regular, Typography.subhead)
                .foregroundStyle(.subtitle)
            Text(text)
                .customFont(.regular, Typography.callout)
                .foregroundStyle(.title)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title.uppercased())
                .customFont(.semibold, Typography.caption)
                .foregroundStyle(.subtitle)
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    private func infoRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .customFont(.regular, Typography.callout)
                .foregroundStyle(.subtitle)
            Spacer(minLength: 12)
            Text(value)
                .customFont(.semibold, Typography.callout)
                .foregroundStyle(.title)
                .multilineTextAlignment(.trailing)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var cardDivider: some View {
        Divider().opacity(0.4).padding(.leading, 14)
    }

    // MARK: - Actions

    @ViewBuilder
    private var actionBar: some View {
        if presenter.canEdit || presenter.canDelete {
            HStack {
                if presenter.canDelete {
                    pillButton("Hapus", systemImage: "trash", tint: .expense) { showDeleteConfirm = true }
                }
                Spacer(minLength: 12)
                if presenter.canEdit {
                    pillButton("Ubah", systemImage: "pencil") { showEdit = true }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(.ultraThinMaterial)
        }
    }

    private func pillButton(_ title: String, systemImage: String, tint: Color = .accent, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage).font(.system(size: 15, weight: .medium))
                Text(title).customFont(.semibold, Typography.body)
            }
            .foregroundStyle(tint)
            .padding(.horizontal, 28)
            .padding(.vertical, 14)
            .overlay(Capsule().stroke(Color.white.opacity(0.14), lineWidth: 1))
        }
        .disabled(presenter.isWorking)
    }

    // MARK: - Helpers

    private func assetAge(_ detail: AssetDetail) -> String {
        var parts: [String] = []
        if let y = detail.assetAgeYear, y > 0 { parts.append("\(y) thn") }
        if let m = detail.assetAgeMonth, m > 0 { parts.append("\(m) bln") }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 60)
    }

    private static func dayFormat(_ date: Date) -> String {
        let f = DateFormatter(); f.locale = Locale(identifier: "id_ID"); f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }

    private static func depreciationLabel(_ method: String) -> String {
        switch method {
        case "straight-line":        return "Garis Lurus"
        case "declining-balance":    return "Saldo Menurun"
        case "sum-of-years":         return "Jumlah Angka Tahun"
        case "units-of-production":  return "Unit Produksi"
        default:                     return method
        }
    }
}
