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

/// Centralised semantic type scale. Every text size in the app maps to one of
/// these steps so the type hierarchy stays consistent across features. Pair a
/// step with a `CustomFontWeight` via `customFont(_:_:)`, e.g.
/// `Text("…").customFont(.semibold, Typography.headline)`.
enum Typography {
    /// Hero metric numbers (e.g. main balance). Largest step.
    static let display: CGFloat = 28
    /// Screen / sheet titles.
    static let largeTitle: CGFloat = 24
    /// Prominent titles, primary list amounts, big card numbers.
    static let title: CGFloat = 22
    /// Section headers.
    static let title2: CGFloat = 20
    /// Card titles, row headlines, list item primary lines.
    static let headline: CGFloat = 17
    /// Default body text, text fields, primary content.
    static let body: CGFloat = 15
    /// Secondary content, status captions, buttons.
    static let callout: CGFloat = 14
    /// Field labels, metadata, secondary lines.
    static let subhead: CGFloat = 13
    /// Small captions.
    static let caption: CGFloat = 12
    /// Tiny badges / overlines. Smallest step.
    static let caption2: CGFloat = 11
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

    // Type scale (Inter weights via `customFont`), backed by `Typography`.
    // Sizes match the Penerimaan / Pengeluaran rows, the reference for all lists.
    static let titleSize: CGFloat = Typography.body      // primary line + trailing amount
    static let metaSize: CGFloat = Typography.caption    // date / number / secondary line
    static let statusSize: CGFloat = Typography.caption2 // status caption
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
