//
//  Formatters.swift
//  Jesuit
//
//  Shared value formatting helpers.
//

import Foundation

extension Double {
    var asCurrency: String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencySymbol = "$"
        f.maximumFractionDigits = 2
        return f.string(from: NSNumber(value: self)) ?? "$0"
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
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.minimumFractionDigits = 2
        f.maximumFractionDigits = 2
        f.groupingSeparator = ","
        let value = f.string(from: NSNumber(value: self)) ?? "0.00"
        return "IDR\(value)"
    }

    /// Indonesian Rupiah, id-ID style, no decimals, `.` thousands separators,
    /// e.g. `Rp 241.637.282.120`, `Rp -27.155.000`.
    var asRupiah: String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 0
        f.groupingSeparator = "."
        f.usesGroupingSeparator = true
        let value = f.string(from: NSNumber(value: self)) ?? "0"
        return "Rp \(value)"
    }

    /// Rupiah with an explicit leading minus glyph for negatives, e.g.
    /// `Rp 491.549.310`, `– Rp 848.008.393`. Used in the summary panels.
    var asSignedRupiah: String {
        self < 0 ? "– \(abs(self).asRupiah)" : asRupiah
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
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.groupingSeparator = "."
        f.usesGroupingSeparator = true
        return f.string(from: NSNumber(value: value)) ?? digits
    }
}

extension Date {
    var short: String {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f.string(from: self)
    }
}
