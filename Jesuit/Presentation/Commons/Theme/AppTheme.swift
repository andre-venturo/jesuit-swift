//
//  AppTheme.swift
//  Jesuit
//
//  Centralised design tokens, adopted from the draft-core-v1 skeleton. Brand
//  and semantic colors resolve to the project's existing asset catalog
//  (Resources/Catalogs/Assets.xcassets/Colors) so light/dark variants stay in
//  one place; the `Color(hex:)` helper is kept for one-off literals.
//

import SwiftUI

/// Centralised design tokens.
enum AppTheme {

    // MARK: - Semantic (backed by the asset catalog)
    static let accent          = Color.accentColor
    static let secondary       = Color.mySecondary
    static let background      = Color.background1
    static let title           = Color.title
    static let subtitle        = Color.subtitle
    static let income          = Color.income
    static let expense         = Color.expense
    static let textFieldBG     = Color.textFieldBG
    static let textFieldStroke = Color.textFieldStroke

    // MARK: - Status (literal fallbacks, no asset equivalent yet)
    static let successGreen = Color(hex: "34C759")
    static let errorRed     = Color(hex: "FF3B30")
    static let warningOrange = Color(hex: "FF9500")
}

/// Shared sizing/spacing for the list tabs (Customers, Penerimaan,
/// Pengeluaran) so rows, insets and type scale stay identical across screens.
enum ListMetrics {
    /// Horizontal inset for rows and section content.
    static let horizontalInset: CGFloat = 16
    /// Vertical padding inside a list row.
    static let rowVerticalPadding: CGFloat = 16
    /// Vertical spacing between stacked lines within a row.
    static let rowLineSpacing: CGFloat = 10

    // Type scale (Inter weights via `customFont`).
    static let titleSize: CGFloat = 20      // primary line + trailing amount
    static let metaSize: CGFloat = 16       // date / number / secondary line
    static let statusSize: CGFloat = 15     // status caption
}

// MARK: - Color from hex
extension Color {
    /// Builds a color from a `RRGGBB` hex string (any non-alphanumeric prefix
    /// such as `#` is ignored).
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
