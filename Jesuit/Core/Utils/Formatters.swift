//
//  Formatters.swift
//  Jesuit
//
//  Shared value formatting helpers.
//

import Foundation

// Cached, configured-once formatters. `NumberFormatter`/`DateFormatter` `init` loads
// ICU data and is expensive; the extensions below run per-row/per-render in lists, so
// reusing shared instances avoids thousands of allocations on scroll. Their formatting
// methods are thread-safe on iOS as long as the formatter isn't mutated after setup —
// none of these are.
private enum NF {
    static let currencyUSD = make { $0.numberStyle = .currency; $0.currencySymbol = "$"; $0.maximumFractionDigits = 2 }
    static let idr = make { $0.numberStyle = .decimal; $0.minimumFractionDigits = 2; $0.maximumFractionDigits = 2; $0.groupingSeparator = "," }
    static let accounting = make { $0.numberStyle = .decimal; $0.minimumFractionDigits = 2; $0.maximumFractionDigits = 2; $0.groupingSeparator = ","; $0.usesGroupingSeparator = true }
    /// Grouped integer, id-ID "." thousands (shared by asGrouped / asRupiah / groupedThousands).
    static let groupedDot = make { $0.numberStyle = .decimal; $0.maximumFractionDigits = 0; $0.groupingSeparator = "."; $0.usesGroupingSeparator = true }
    /// Foreign currency: "." thousands, "," decimals, 2 fraction digits.
    static let foreign = make { $0.numberStyle = .decimal; $0.groupingSeparator = "."; $0.decimalSeparator = ","; $0.usesGroupingSeparator = true; $0.minimumFractionDigits = 2; $0.maximumFractionDigits = 2 }

    private static func make(_ configure: (NumberFormatter) -> Void) -> NumberFormatter {
        let f = NumberFormatter(); configure(f); return f
    }
}

private enum DF {
    static let monthDay = make("MMM d")
    static let dayMonthYear = make("dd/MM/yyyy")

    private static func make(_ format: String) -> DateFormatter {
        let f = DateFormatter(); f.dateFormat = format; return f
    }
}

extension Double {
    var asCurrency: String {
        NF.currencyUSD.string(from: NSNumber(value: self)) ?? "$0"
    }

    var asCompactCurrency: String {
        if abs(self) >= 1000 {
            return String(format: "$%.1fK", self / 1000)
        }
        return asCurrency
    }

    /// Compact signed value for chart axes, e.g. `0`, `-10K`, `-1.5M`.
    var asCompactSigned: String {
        let sign = self < 0 ? "-" : ""
        let v = abs(self)
        switch v {
        case 1_000_000...:
            return "\(sign)\(String(format: "%g", (v / 1_000_000).rounded(toPlaces: 1)))M"
        case 1_000...:
            return "\(sign)\(String(format: "%g", (v / 1_000).rounded(toPlaces: 1)))K"
        default:
            return String(format: "%g", self)
        }
    }

    private func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }

    /// Indonesian Rupiah, e.g. `IDR0.00`.
    var asIDR: String {
        let value = NF.idr.string(from: NSNumber(value: self)) ?? "0.00"
        return "IDR\(value)"
    }

    /// Financial-statement style: grouped, two decimals, no currency symbol,
    /// e.g. `3,500,000,000.00`. Used by the Neraca statement.
    var asAccounting: String {
        NF.accounting.string(from: NSNumber(value: self)) ?? "0.00"
    }

    /// Grouped integer, no currency symbol, id-ID `.` thousands separators,
    /// e.g. `102.932.122`. For columnar tables where the column header already
    /// names the currency (Debit / Kredit ledger columns).
    var asGrouped: String {
        NF.groupedDot.string(from: NSNumber(value: self)) ?? "0"
    }

    /// Indonesian Rupiah, id-ID style, no decimals, `.` thousands separators,
    /// e.g. `Rp 241.637.282.120`, `Rp -27.155.000`.
    var asRupiah: String {
        let value = NF.groupedDot.string(from: NSNumber(value: self)) ?? "0"
        return "Rp \(value)"
    }

    /// Rupiah with an explicit leading minus glyph for negatives, e.g.
    /// `Rp 491.549.310`, `– Rp 848.008.393`. Used in the summary panels.
    var asSignedRupiah: String {
        self < 0 ? "– \(abs(self).asRupiah)" : asRupiah
    }

    /// Formats an amount in the given ISO currency code, id-ID style (`.`
    /// thousands, `,` decimals). IDR has no decimals and a `Rp ` prefix; every
    /// other currency uses its symbol (e.g. `$`) and 2 decimals — e.g.
    /// `Rp 690.002`, `-$421.650,00`. Falls back to the code as a prefix for
    /// unknown currencies (e.g. `SGD 1.000,00`).
    func asCurrency(_ code: String?) -> String {
        let currency = (code ?? "IDR").uppercased()
        if currency == "IDR" { return asRupiah }

        let sign = self < 0 ? "-" : ""
        let value = NF.foreign.string(from: NSNumber(value: abs(self))) ?? "0,00"
        let symbol = Self.currencySymbol(currency)
        // Symbols hug the number (`$1.000,00`); ISO-code fallbacks get a space.
        let separator = symbol == currency ? " " : ""
        return "\(sign)\(symbol)\(separator)\(value)"
    }

    /// Common currency symbols; unknown codes fall back to the code itself.
    private static func currencySymbol(_ code: String) -> String {
        switch code {
        case "USD": return "$"
        case "EUR": return "€"
        case "GBP": return "£"
        case "JPY": return "¥"
        case "SGD": return "S$"
        case "AUD": return "A$"
        default:    return code
        }
    }

    /// Compact Indonesian Rupiah with magnitude suffixes (rb/jt/M/T), e.g.
    /// `Rp254,1 M`, `-Rp12,4 M`, `Rp0`. Keeps large finance figures readable on
    /// one line; `.` is the decimal mark (id-ID style).
    var asCompactIDR: String {
        let sign = self < 0 ? "-" : ""
        let v = abs(self)
        func num(_ value: Double) -> String {
            String(format: "%g", value.rounded(toPlaces: 1)).replacingOccurrences(of: ".", with: ",")
        }
        switch v {
        case 1_000_000_000_000...:
            return "\(sign)Rp\(num(v / 1_000_000_000_000)) T"
        case 1_000_000_000...:
            return "\(sign)Rp\(num(v / 1_000_000_000)) M"
        case 1_000_000...:
            return "\(sign)Rp\(num(v / 1_000_000)) jt"
        case 1_000...:
            return "\(sign)Rp\(num(v / 1_000)) rb"
        default:
            return "\(sign)Rp\(num(v))"
        }
    }
}

extension String {
    /// Groups a digit-only string with `.` thousands separators (id-ID style),
    /// e.g. `"7000"` -> `"7.000"`. Non-digits are ignored; empty stays empty.
    var groupedThousands: String {
        let digits = filter(\.isNumber)
        guard let value = Int(digits) else { return "" }
        return NF.groupedDot.string(from: NSNumber(value: value)) ?? digits
    }
}

extension Date {
    /// `MMM d`, e.g. `Jun 9` — chart axes / compact labels.
    var short: String { DF.monthDay.string(from: self) }

    /// `dd/MM/yyyy`, e.g. `09/06/2026` — the transaction list rows.
    var dayMonthYear: String { DF.dayMonthYear.string(from: self) }
}
