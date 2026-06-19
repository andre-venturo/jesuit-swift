//
//  AttachmentsField.swift
//  Jesuit
//
//  "Lampiran" picker used in the cash-transaction "Tambah Baris" sheets: a row
//  of image thumbnails (with a size badge) plus an add tile that opens the photo
//  library. Files are carried as `CashAttachment` and uploaded as `attachments_n`
//  multipart parts on save.
//

import SwiftUI
import PhotosUI

struct AttachmentsField: View {
    /// Newly-picked local files (uploaded on save).
    @Binding var attachments: [CashAttachment]
    /// Already-uploaded attachments shown when editing (read from the server).
    var existing: [CashLineAttachment] = []

    @State private var selection: [PhotosPickerItem] = []
    @State private var isLoading = false
    @State private var previewImage: PreviewImage?

    private let tile: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lampiran")
                .customFont(.medium, Typography.body)
                .foregroundStyle(.subtitle)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(existing) { attachment in
                        existingThumbnail(attachment)
                    }
                    ForEach(attachments) { attachment in
                        thumbnail(attachment)
                    }
                    addTile
                }
            }
        }
        .onChange(of: selection) { _, items in
            guard !items.isEmpty else { return }
            Task { await load(items) }
        }
        .fullScreenCover(item: $previewImage) { ImagePreviewSheet(image: $0) }
    }

    // MARK: - Tiles

    /// An already-uploaded attachment: remote image, read-only (no remove —
    /// deletion isn't exposed by the API here).
    private func existingThumbnail(_ attachment: CashLineAttachment) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if attachment.isImage, let url = URL(string: attachment.fileUrl) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFill()
                        case .empty:
                            ProgressView().tint(.accent)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        default:
                            Image(systemName: "photo")
                                .font(.system(size: 28))
                                .foregroundStyle(.subtitle)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    }
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 28))
                        .foregroundStyle(.subtitle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: tile, height: tile)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture {
                if let preview = PreviewImage(attachment) { previewImage = preview }
            }

            Text(attachment.sizeLabel)
                .customFont(.medium, Typography.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(6)
        }
        .frame(width: tile, height: tile)
    }

    private func thumbnail(_ attachment: CashAttachment) -> some View {
        ZStack(alignment: .bottomLeading) {
            Group {
                if let image = UIImage(data: attachment.data) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "doc")
                        .font(.system(size: 28))
                        .foregroundStyle(.subtitle)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: tile, height: tile)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .onTapGesture {
                if let preview = PreviewImage(attachment) { previewImage = preview }
            }

            Text(attachment.sizeLabel)
                .customFont(.medium, Typography.caption2)
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color.black.opacity(0.6))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(6)

            Button {
                attachments.removeAll { $0.id == attachment.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 20))
                    .foregroundStyle(.white, .black.opacity(0.6))
            }
            .padding(4)
            .frame(width: tile, height: tile, alignment: .topTrailing)
        }
        .frame(width: tile, height: tile)
    }

    private var addTile: some View {
        PhotosPicker(selection: $selection, maxSelectionCount: 5, matching: .images) {
            VStack(spacing: 6) {
                if isLoading {
                    ProgressView().tint(.accent)
                } else {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .medium))
                    Text("Tambah")
                        .customFont(.medium, Typography.subhead)
                }
            }
            .foregroundStyle(.subtitle)
            .frame(width: tile, height: tile)
            .background(Color.textFieldBG)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .disabled(isLoading)
    }

    // MARK: - Loading

    /// Reads each picked item's bytes into a `CashAttachment`, inferring a
    /// filename + mime type from its supported content types.
    private func load(_ items: [PhotosPickerItem]) async {
        isLoading = true
        var loaded: [CashAttachment] = []
        for item in items {
            guard let data = try? await item.loadTransferable(type: Data.self) else { continue }
            let (ext, mime) = Self.fileInfo(for: item)
            loaded.append(
                CashAttachment(
                    filename: "lampiran-\(loaded.count + attachments.count + 1).\(ext)",
                    mimeType: mime,
                    data: data
                )
            )
        }
        attachments.append(contentsOf: loaded)
        selection = []
        isLoading = false
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
}
