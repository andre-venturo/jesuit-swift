//
//  CustomFont.swift
//  Jesuit
//
//  Created by admin on 23/11/25.
//

import SwiftUI

extension Font {
    /// A custom font initializer for the "Inter" font family.
    ///
    /// **Important**: Before using this custom font, make sure the font files are included in the project directory
    /// and properly registered in the `Info.plist` file.
    /// The font files should be added under "Copy Bundle Resources" in the project settings and the `Info.plist`
    /// should include the font under the `Fonts provided by application` key.
    ///
    /// - Parameters:
    ///   - fontType: The desired font weight (e.g., light, regular, medium, bold, black).
    ///   - size: The size of the font.
    /// - Returns: A `Font` object with the specified font type and size.
    static let customFont: (CustomFontWeight, CGFloat) -> Font = { fontType, size in
        switch fontType {
        case .light:
            Font.custom("Inter-Light", fixedSize: size)
        case .regular:
            Font.custom("Inter-Regular", fixedSize: size)
        case .medium:
            Font.custom("Inter-Medium", fixedSize: size)
        case .bold:
            Font.custom("Inter-Bold", fixedSize: size)
        case .semibold:
            Font.custom("Inter-SemiBold", fixedSize: size)
        }
    }
}

/// Custom extension for the `Text` view to apply custom "Inter" fonts.
///
/// This extension allows you to apply different weights and sizes of the "Inter" font to a `Text` view.
extension Text {
    /// Applies a custom font to the `Text` view.
    ///
    /// **Important**: Make sure the font is available in the project and registered in the `Info.plist` file
    /// before using this method.
    ///
    /// - Parameters:
    ///   - fontWeight: The desired font weight.
    ///   - size: The font size.
    /// - Returns: A `Text` view with the specified custom font applied.
    func customFont(_ fontWeight: CustomFontWeight, _ size: CGFloat) -> Text {
        return self.font(.customFont(fontWeight, size))
    }
}
