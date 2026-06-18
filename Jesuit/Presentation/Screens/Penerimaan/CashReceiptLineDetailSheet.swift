//
//  CashReceiptLineDetailSheet.swift
//  Jesuit
//
//  Detail for a single "Detail Baris" row: account, amount, description and the
//  line's attachments rendered as large previews (tap to open the file). When the
//  parent transaction is still editable, a "Tambah Lampiran" picker uploads files
//  to the line (POST /cash-transactions/{id}/lines/{lineId}/attachments).
//

import SwiftUI
import PhotosUI

struct CashReceiptLineDetailSheet: View {
    let line: CashReceiptLine
    let transactionId: String
    /// Whether the transaction is still mutable — gates the upload control.
    let canEdit: Bool
    /// Called after a successful upload so the parent detail reloads.
    let onChanged: () -> Void

    @Environment(\.dismiss) private var dismiss

    private let repository = AppDI.shared.resolver(CashReceiptRepositoryProtocol.self)

    /// Local copy so freshly uploaded attachments appear without a reload.
    @State private var attachments: [CashLineAttachment]
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var isUploading = false
    @State private var errorMessage: String?

    init(
        line: CashReceiptLine,
        transactionId: String,
        canEdit: Bool,
        onChanged: @escaping () -> Void
    ) {
        self.line = line
        self.transactionId = transactionId
        self.canEdit = canEdit
        self.onChanged = onChanged
        _attachments = State(initialValue: line.attachments)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(line.accountName)
                            .customFont(.semibold, Typography.headline)
                            .foregroundStyle(.title)
                        if line.isPinned {
                            Text("Utama")
                                .customFont(.medium, Typography.caption2)
                                .foregroundStyle(.accent)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(Color.accentColor.opacity(0.14))
                                .clipShape(Capsule())
                        }
                    }

                    field("Jumlah", line.amount.asRupiah)

                    if !line.description.isEmpty {
                        field("Deskripsi", line.description)
                    }

                    attachmentsSection
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .frame(maxWidth: .infinity)
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Baris \(line.lineNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.subtitle)
                }
            }
        }
        .onChange(of: pickerItems) { _, items in
            guard !items.isEmpty else { return }
            Task { await upload(items) }
        }
    }

    // MARK: - Attachments

    @ViewBuilder
    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lampiran (\(attachments.count))")
                .customFont(.medium, Typography.body)
                .foregroundStyle(.subtitle)

            if attachments.isEmpty {
                Text("Tidak ada lampiran.")
                    .customFont(.regular, Typography.callout)
                    .foregroundStyle(.subtitle)
            } else {
                ForEach(attachments) { attachment in
                    attachmentCard(attachment)
                }
            }

            if let errorMessage {
                Text(errorMessage)
                    .customFont(.medium, Typography.subhead)
                    .foregroundStyle(.expense)
            }

            if canEdit {
                addButton
            }
        }
    }

    private var addButton: some View {
        PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
            HStack(spacing: 8) {
                if isUploading {
                    ProgressView().tint(.accent)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Tambah Lampiran")
                        .customFont(.semibold, Typography.body)
                }
            }
            .foregroundStyle(.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.accentColor.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        }
        .disabled(isUploading)
        .padding(.top, 4)
    }

    private func attachmentCard(_ attachment: CashLineAttachment) -> some View {
        Link(destination: URL(string: attachment.fileUrl) ?? URL(string: "https://wizhub.id")!) {
            VStack(alignment: .leading, spacing: 0) {
                if attachment.isImage, let url = URL(string: attachment.fileUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        case .failure:
                            preview(systemImage: "photo")
                        case .empty:
                            ProgressView().tint(.accent)
                                .frame(maxWidth: .infinity, minHeight: 180)
                        @unknown default:
                            preview(systemImage: "doc")
                        }
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    preview(systemImage: "doc")
                }

                HStack(spacing: 8) {
                    Image(systemName: "paperclip")
                        .font(.system(size: 13))
                        .foregroundStyle(.subtitle)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(attachment.fileName)
                            .customFont(.medium, Typography.callout)
                            .foregroundStyle(.title)
                            .lineLimit(1)
                        Text(attachment.sizeLabel)
                            .customFont(.regular, Typography.caption)
                            .foregroundStyle(.subtitle)
                    }
                    Spacer()
                    Image(systemName: "arrow.up.right.square")
                        .font(.system(size: 15))
                        .foregroundStyle(.accent)
                }
                .padding(12)
            }
            .background(Color.textFieldBG)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
    }

    private func preview(systemImage: String) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 40))
            .foregroundStyle(.subtitle)
            .frame(maxWidth: .infinity, minHeight: 140)
            .background(Color.black.opacity(0.05))
    }

    // MARK: - Upload

    private func upload(_ items: [PhotosPickerItem]) async {
        isUploading = true
        errorMessage = nil
        var didUpload = false
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let (ext, mime) = Self.fileInfo(for: item)
            let attachment = CashAttachment(
                filename: "lampiran-\(attachments.count + 1).\(ext)",
                mimeType: mime,
                data: data
            )
            do {
                let saved = try await repository.uploadLineAttachment(
                    transactionId: transactionId,
                    lineId: line.id,
                    attachment: attachment
                )
                attachments.append(saved)
                didUpload = true
            } catch {
                errorMessage = LoginPresenter.message(for: error)
            }
        }
        pickerItems = []
        isUploading = false
        if didUpload { onChanged() }
    }

    /// Best-effort (extension, mimeType) from a picker item's content type.
    private static func fileInfo(for item: PhotosPickerItem) -> (String, String) {
        if let type = item.supportedContentTypes.first {
            if type.conforms(to: .png) { return ("png", "image/png") }
            if type.conforms(to: .heic) { return ("heic", "image/heic") }
            if let ext = type.preferredFilenameExtension,
               let mime = type.preferredMIMEType {
                return (ext, mime)
            }
        }
        return ("jpeg", "image/jpeg")
    }

    // MARK: - Helpers

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .customFont(.regular, Typography.subhead)
                .foregroundStyle(.subtitle)
            Text(value)
                .customFont(.semibold, Typography.body)
                .foregroundStyle(.title)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
