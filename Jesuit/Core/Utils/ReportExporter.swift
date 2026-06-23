//
//  ReportExporter.swift
//  Jesuit
//
//  Builds shareable PDF and CSV files for the Laporan Arus Kas (cash journal).
//  No third-party deps: CSV is a plain string (opens in Excel/Numbers/Sheets),
//  PDF is drawn with the native UIGraphicsPDFRenderer. Layout mirrors the web
//  "Jurnal Umum" table: Tanggal · No · Akun · Deskripsi · Debit · Kredit + totals.
//

import UIKit

enum ReportExporter {
    static let title = "Laporan Arus Kas"
    private static let columns = ["Tanggal", "No. Transaksi", "Akun", "Deskripsi", "Debit (Rp)", "Kredit (Rp)"]

    private static func dateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "id_ID")
        f.dateFormat = "dd/MM/yyyy"
        return f.string(from: date)
    }

    private static func fileName(_ label: String, ext: String) -> String {
        let safe = label.components(separatedBy: CharacterSet(charactersIn: "/\\:*?\"<>|")).joined(separator: "-")
        return "Laporan \(safe).\(ext)"
    }

    // MARK: - CSV

    static func csvURL(summary: ReportSummary, orgName: String, periodLabel: String) throws -> URL {
        var lines: [String] = []
        lines.append(csvField(orgName))
        lines.append(csvField(title))
        lines.append("Periode," + csvField(periodLabel))
        lines.append("")
        lines.append(columns.map(csvField).joined(separator: ","))
        for e in summary.journalEntries {
            lines.append([
                dateString(e.date), e.number, e.account, e.description,
                e.debit > 0 ? String(Int(e.debit)) : "",
                e.kredit > 0 ? String(Int(e.kredit)) : ""
            ].map(csvField).joined(separator: ","))
        }
        lines.append(["Total (Rp)", "", "", "",
                      String(Int(summary.penerimaanTotal)),
                      String(Int(summary.pengeluaranTotal))].map(csvField).joined(separator: ","))

        // BOM so Excel reads UTF-8 (accented chars) correctly.
        let csv = "\u{FEFF}" + lines.joined(separator: "\r\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(periodLabel, ext: "csv"))
        try csv.data(using: .utf8)?.write(to: url)
        return url
    }

    /// RFC-4180 escaping: wrap in quotes when the value has a comma, quote or newline.
    private static func csvField(_ value: String) -> String {
        guard value.contains(where: { $0 == "," || $0 == "\"" || $0 == "\n" || $0 == "\r" }) else { return value }
        return "\"" + value.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }

    // MARK: - PDF

    private static let pageSize = CGSize(width: 595, height: 842)  // A4 @ 72dpi
    private static let margin: CGFloat = 40
    /// Relative column widths: Tanggal, No, Akun, Deskripsi, Debit, Kredit.
    private static let colWeights: [CGFloat] = [0.12, 0.18, 0.24, 0.22, 0.12, 0.12]

    static func pdfURL(summary: ReportSummary, orgName: String, periodLabel: String) throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(periodLabel, ext: "pdf"))
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(origin: .zero, size: pageSize))
        try renderer.writePDF(to: url) { ctx in
            var cursor = PDFCursor(ctx: ctx, pageSize: pageSize, margin: margin)
            cursor.beginPage()

            cursor.centered(orgName, font: .systemFont(ofSize: 12), color: .darkGray)
            cursor.centered(title, font: .boldSystemFont(ofSize: 18))
            cursor.centered(periodLabel, font: .systemFont(ofSize: 11), color: .darkGray)
            cursor.gap(14)

            let widths = cursor.columnWidths(colWeights)
            cursor.row(columns, widths: widths, font: .boldSystemFont(ofSize: 9), color: .darkGray, rightCols: [4, 5])
            cursor.rule()
            for e in summary.journalEntries {
                cursor.row([
                    dateString(e.date), e.number, e.account, e.description,
                    e.debit > 0 ? e.debit.asGroupedInt : "—",
                    e.kredit > 0 ? e.kredit.asGroupedInt : "—"
                ], widths: widths, font: .systemFont(ofSize: 9), rightCols: [4, 5])
            }
            cursor.rule()
            cursor.row(["Total (Rp)", "", "", "",
                        summary.penerimaanTotal.asGroupedInt,
                        summary.pengeluaranTotal.asGroupedInt],
                       widths: widths, font: .boldSystemFont(ofSize: 9), rightCols: [4, 5])
        }
        return url
    }
}

private extension Double {
    /// Grouped integer rupiah without the "Rp" prefix (e.g. "1.200.000"), for tables.
    var asGroupedInt: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "id_ID")
        f.maximumFractionDigits = 0
        return f.string(from: NSNumber(value: self)) ?? String(Int(self))
    }
}

/// Minimal top-down text/table cursor over a paginated PDF context.
private struct PDFCursor {
    let ctx: UIGraphicsPDFRendererContext
    let pageSize: CGSize
    let margin: CGFloat
    var y: CGFloat = 0

    private var maxY: CGFloat { pageSize.height - margin }
    private var width: CGFloat { pageSize.width - margin * 2 }

    mutating func beginPage() {
        ctx.beginPage()
        y = margin
    }

    private mutating func ensure(_ height: CGFloat) {
        if y + height > maxY { beginPage() }
    }

    mutating func gap(_ h: CGFloat) { y += h }

    mutating func centered(_ string: String, font: UIFont, color: UIColor = .black) {
        let height = font.lineHeight + 3
        ensure(height)
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        string.draw(in: CGRect(x: margin, y: y, width: width, height: height),
                    withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
        y += height
    }

    func columnWidths(_ weights: [CGFloat]) -> [CGFloat] { weights.map { $0 * width } }

    mutating func rule() {
        ensure(6)
        let path = UIBezierPath()
        path.move(to: CGPoint(x: margin, y: y + 1))
        path.addLine(to: CGPoint(x: margin + width, y: y + 1))
        UIColor.lightGray.setStroke()
        path.lineWidth = 0.5
        path.stroke()
        y += 4
    }

    mutating func row(_ cells: [String], widths: [CGFloat], font: UIFont,
                      color: UIColor = .black, rightCols: Set<Int> = []) {
        let height = font.lineHeight + 4
        ensure(height)
        var x = margin
        for (index, cell) in cells.enumerated() {
            let w = index < widths.count ? widths[index] : 0
            let style = NSMutableParagraphStyle()
            style.lineBreakMode = .byTruncatingTail
            style.alignment = rightCols.contains(index) ? .right : .left
            cell.draw(in: CGRect(x: x, y: y, width: w - 4, height: height),
                      withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: style])
            x += w
        }
        y += height
    }
}
