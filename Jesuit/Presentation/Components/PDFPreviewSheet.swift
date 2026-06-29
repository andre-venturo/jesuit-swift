//
//  PDFPreviewSheet.swift
//  Jesuit
//
//  Full-screen QuickLook preview for an exported file (the report PDF). QuickLook
//  renders the document and already provides the native share/print button, so this
//  doubles as the "Cetak PDF" entry point — preview first, then print/share.
//

import SwiftUI
import QuickLook

struct PDFPreviewSheet: UIViewControllerRepresentable {
    let url: URL
    var onClose: () -> Void

    func makeUIViewController(context: Context) -> UINavigationController {
        let preview = QLPreviewController()
        preview.dataSource = context.coordinator
        // QuickLook adds its own share/print button on the right; we add Tutup on the
        // left since a fullScreenCover can't be swiped away.
        preview.navigationItem.leftBarButtonItem = UIBarButtonItem(
            title: "Tutup", style: .plain, target: context.coordinator, action: #selector(Coordinator.close)
        )
        return UINavigationController(rootViewController: preview)
    }

    func updateUIViewController(_ controller: UINavigationController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(url: url, onClose: onClose) }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        let url: URL
        let onClose: () -> Void

        init(url: URL, onClose: @escaping () -> Void) {
            self.url = url
            self.onClose = onClose
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int { 1 }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }

        @objc func close() { onClose() }
    }
}
