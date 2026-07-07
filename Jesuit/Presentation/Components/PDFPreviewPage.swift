//
//  PDFPreviewPage.swift
//  Jesuit
//
//  Pushed full-page preview for an exported report PDF. PDFKit renders the
//  document; the share toolbar button (which includes Print) doubles as the
//  "Cetak PDF" action — preview first, then print/share.
//

import SwiftUI
import PDFKit

struct PDFPreviewPage: View {
    let url: URL

    var body: some View {
        PDFKitView(url: url)
            .ignoresSafeArea(edges: .bottom)
            .navigationTitle(ReportExporter.title)
            .navigationBarTitleDisplayMode(.inline)
            // Tab bar stays hidden via the push root (MoreScreen) — no modifier here.
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    ShareLink(item: url) {
                        Image(systemName: "square.and.arrow.up").foregroundStyle(.accent)
                    }
                }
            }
    }
}

private struct PDFKitView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> PDFView {
        let view = PDFView()
        view.document = PDFDocument(url: url)
        view.autoScales = true
        return view
    }

    func updateUIView(_ view: PDFView, context: Context) {}
}
