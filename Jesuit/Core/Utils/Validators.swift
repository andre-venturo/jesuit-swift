//
//  Validators.swift
//  Jesuit
//
//  Pure-function form validators adopted from the draft-core-v1 skeleton.
//

import Foundation

/// Pure-function validators — no dependencies, no side effects.
nonisolated enum Validators {

    /// Returns an error message if invalid, `nil` if valid.
    static func email(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            return AppStrings.fieldRequired
        }
        let regex = #"^[\w\-\.]+@([\w\-]+\.)+[\w\-]{2,4}$"#
        let isValid = value.range(of: regex, options: .regularExpression) != nil
        return isValid ? nil : AppStrings.invalidEmail
    }

    static func password(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return AppStrings.fieldRequired }
        return value.count >= 8 ? nil : AppStrings.passwordTooShort
    }

    static func confirmPassword(_ value: String?, original: String) -> String? {
        guard let value, !value.isEmpty else { return AppStrings.fieldRequired }
        return value == original ? nil : AppStrings.passwordsDoNotMatch
    }

    static func required(_ value: String?) -> String? {
        guard let value, !value.trimmingCharacters(in: .whitespaces).isEmpty else {
            return AppStrings.fieldRequired
        }
        return nil
    }
}
