//
//  ImagePreviewSheet.swift
//  Jesuit
//
//  Full-screen, zoomable preview for an image attachment. Opened by tapping an
//  image thumbnail in the cash-transaction detail / line sheets. Non-image
//  attachments still open in the browser via a `Link`.
//

import SwiftUI

/// One previewable image, either a remote attachment URL or a locally-picked
/// (not-yet-uploaded) image's bytes.
struct PreviewImage: Identifiable {
    enum Source {
        case remote(URL)
        case local(UIImage)
    }

    let id: String
    let source: Source
    let title: String

    /// Remote (already-uploaded) image attachment.
    init?(_ attachment: CashLineAttachment) {
        guard attachment.isImage, let url = URL(string: attachment.fileUrl) else { return nil }
        self.id = attachment.id
        self.source = .remote(url)
        self.title = attachment.fileName
    }

    /// Locally-picked image attachment (carries raw bytes, no URL yet).
    init?(_ attachment: CashAttachment) {
        guard let image = UIImage(data: attachment.data) else { return nil }
        self.id = attachment.id.uuidString
        self.source = .local(image)
        self.title = attachment.filename
    }
}

struct ImagePreviewSheet: View {
    let image: PreviewImage

    @Environment(\.dismiss) private var dismiss

    @State private var scale: CGFloat = 1
    @State private var lastScale: CGFloat = 1
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()

                switch image.source {
                case .local(let uiImage):
                    zoomable(Image(uiImage: uiImage))
                case .remote(let url):
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img):
                            zoomable(img)
                        case .failure:
                            stateIcon("exclamationmark.triangle", "Gagal memuat gambar")
                        case .empty:
                            ProgressView().tint(.white)
                        @unknown default:
                            stateIcon("photo", "")
                        }
                    }
                }
            }
            .navigationTitle(image.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .toolbarBackground(.black, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Tutup") { dismiss() }.foregroundStyle(.white)
                }
                if case .remote(let url) = image.source {
                    ToolbarItem(placement: .primaryAction) {
                        Link(destination: url) {
                            Image(systemName: "safari").foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }

    /// Applies the shared zoom/pan/double-tap gestures to a resolved image.
    private func zoomable(_ image: Image) -> some View {
        image.resizable().scaledToFit()
            .scaleEffect(scale)
            .offset(offset)
            .gesture(magnification)
            .gesture(drag)
            .onTapGesture(count: 2) { resetOrZoom() }
    }

    // MARK: - Gestures

    private var magnification: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                scale = min(max(lastScale * value, 1), 5)
            }
            .onEnded { _ in
                lastScale = scale
                if scale <= 1 { withAnimation(.easeOut(duration: 0.2)) { resetTransform() } }
            }
    }

    private var drag: some Gesture {
        DragGesture()
            .onChanged { value in
                if scale > 1 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                } else {
                    // Not zoomed: track a vertical swipe-to-dismiss.
                    offset = CGSize(width: 0, height: value.translation.height)
                }
            }
            .onEnded { value in
                if scale > 1 {
                    lastOffset = offset
                } else if value.translation.height > 120 {
                    dismiss()
                } else {
                    withAnimation(.easeOut(duration: 0.2)) { offset = .zero }
                }
            }
    }

    private func resetOrZoom() {
        withAnimation(.easeInOut(duration: 0.25)) {
            if scale > 1 {
                resetTransform()
            } else {
                scale = 2.5
                lastScale = 2.5
            }
        }
    }

    private func resetTransform() {
        scale = 1; lastScale = 1; offset = .zero; lastOffset = .zero
    }

    private func stateIcon(_ systemImage: String, _ text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 40))
            if !text.isEmpty {
                Text(text).customFont(.medium, Typography.body)
            }
        }
        .foregroundStyle(.white.opacity(0.7))
    }
}
