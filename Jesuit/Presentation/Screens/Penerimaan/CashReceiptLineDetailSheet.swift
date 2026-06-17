//
//  CashReceiptLineDetailSheet.swift
//  Jesuit
//
//  Detail for a single "Detail Baris" row: account, amount, description and the
//  line's attachments rendered as large previews (tap to open the file).
//

import SwiftUI

struct CashReceiptLineDetailSheet: View {
    let line: CashReceiptLine

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(alignment: .top, spacing: 8) {
                        Text(line.accountName)
                            .customFont(.semibold, 18)
                            .foregroundStyle(.title)
                        if line.isPinned {
                            Text("Utama")
                                .customFont(.medium, 11)
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
                .padding(20)
            }
            .background(Color.background1.ignoresSafeArea())
            .navigationTitle("Baris \(line.lineNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.subtitle)
                }
            }
        }
    }

    // MARK: - Attachments

    @ViewBuilder
    private var attachmentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Lampiran (\(line.attachments.count))")
                .customFont(.medium, 15)
                .foregroundStyle(.subtitle)

            if line.attachments.isEmpty {
                Text("Tidak ada lampiran.")
                    .customFont(.regular, 14)
                    .foregroundStyle(.subtitle)
            } else {
                ForEach(line.attachments) { attachment in
                    attachmentCard(attachment)
                }
            }
        }
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
                            .customFont(.medium, 14)
                            .foregroundStyle(.title)
                            .lineLimit(1)
                        Text(attachment.sizeLabel)
                            .customFont(.regular, 12)
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

    // MARK: - Helpers

    private func field(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .customFont(.regular, 13)
                .foregroundStyle(.subtitle)
            Text(value)
                .customFont(.semibold, 16)
                .foregroundStyle(.title)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
