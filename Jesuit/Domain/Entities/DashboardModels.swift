//
//  DashboardModels.swift
//  Jesuit
//
//  Domain entities for the dashboard feature.
//

import Foundation

struct KPI: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let amount: Double
    let deltaPercent: Double
    let systemImage: String
}

struct Invoice: Identifiable, Sendable {
    enum Status: String, Sendable {
        case paid = "Paid"
        case pending = "Pending"
        case overdue = "Overdue"
        case draft = "Draft"
    }

    let id = UUID()
    let number: String
    let customer: String
    let amount: Double
    let dueDate: Date
    let status: Status
}

struct Expense: Identifiable, Sendable {
    /// Billing state shown as the row's status line.
    enum Billing: String, Sendable {
        case nonBillable = "Non-Billable"
        case unbilled    = "Unbilled"
        case invoiced    = "Invoiced"
    }

    let id = UUID()
    let category: String
    let vendor: String
    let amount: Double
    let date: Date
    let systemImage: String
    var billing: Billing = .nonBillable
}

struct CashflowPoint: Identifiable, Sendable {
    let id = UUID()
    let month: String
    let income: Double
    let expense: Double
}

// MARK: - Cash Flow (dashboard area chart)

/// Selectable range for the dashboard Cash Flow card. The prev/next stepper
/// shifts the range by the preset's natural unit (day / week / month / year).
enum CashFlowPeriod: String, CaseIterable, Identifiable, Sendable {
    case hariIni   = "Hari Ini"
    case mingguIni = "Minggu Ini"
    case bulanIni  = "Bulan Ini"
    case bulanLalu = "Bulan Lalu"
    case tahunIni  = "Tahun Ini"
    case tahunLalu = "Tahun Lalu"

    var id: String { rawValue }

    /// Calendar unit the prev/next stepper moves by.
    private var unit: Calendar.Component {
        switch self {
        case .hariIni:              return .day
        case .mingguIni:            return .weekOfYear
        case .bulanIni, .bulanLalu: return .month
        case .tahunIni, .tahunLalu: return .year
        }
    }

    /// Offset baked into the preset (e.g. "Bulan Lalu" starts a month back).
    private var baseOffset: Int {
        switch self {
        case .bulanLalu, .tahunLalu: return -1
        default:                     return 0
        }
    }

    private static func calendar(_ base: Calendar) -> Calendar {
        var cal = base
        cal.firstWeekday = 2 // Monday-based weeks
        return cal
    }

    /// The inclusive `[start, end]` range for this preset, shifted by `offset`
    /// units. Drives the dashboard endpoints' `start_date`/`end_date` params.
    func dateRange(offset: Int = 0, now: Date = .now, calendar baseCal: Calendar = .current) -> (start: Date, end: Date) {
        let cal = Self.calendar(baseCal)
        let step = baseOffset + offset
        let startOfDay = cal.startOfDay(for: now)
        switch unit {
        case .day:
            let start = cal.date(byAdding: .day, value: step, to: startOfDay) ?? startOfDay
            let end = cal.date(byAdding: DateComponents(day: 1, second: -1), to: start) ?? start
            return (start, end)
        case .weekOfYear:
            let base = cal.dateInterval(of: .weekOfYear, for: now)?.start ?? startOfDay
            let start = cal.date(byAdding: .weekOfYear, value: step, to: base) ?? base
            let end = cal.date(byAdding: DateComponents(day: 7, second: -1), to: start) ?? start
            return (start, end)
        case .month:
            let base = cal.date(from: cal.dateComponents([.year, .month], from: now)) ?? startOfDay
            let start = cal.date(byAdding: .month, value: step, to: base) ?? base
            let end = cal.date(byAdding: DateComponents(month: 1, second: -1), to: start) ?? start
            return (start, end)
        default: // .year
            let base = cal.date(from: cal.dateComponents([.year], from: now)) ?? startOfDay
            let start = cal.date(byAdding: .year, value: step, to: base) ?? base
            let end = cal.date(byAdding: DateComponents(year: 1, second: -1), to: start) ?? start
            return (start, end)
        }
    }

    /// Center label for the stepper, in id-ID, e.g. `Januari 2026`, `2026`,
    /// `15 Jan 2026`, `12 – 18 Jan 2026`.
    func steppedLabel(offset: Int = 0, now: Date = .now, calendar baseCal: Calendar = .current) -> String {
        let range = dateRange(offset: offset, now: now, calendar: baseCal)
        let f = DateFormatter(); f.locale = Locale(identifier: "id_ID")
        switch unit {
        case .day:
            f.dateFormat = "d MMM yyyy"
            return f.string(from: range.start)
        case .weekOfYear:
            f.dateFormat = "d MMM"
            let endF = DateFormatter(); endF.locale = Locale(identifier: "id_ID"); endF.dateFormat = "d MMM yyyy"
            return "\(f.string(from: range.start)) – \(endF.string(from: range.end))"
        case .month:
            f.dateFormat = "MMMM yyyy"
            return f.string(from: range.start)
        default:
            f.dateFormat = "yyyy"
            return f.string(from: range.start)
        }
    }
}

/// One point on the cumulative cash-balance line (the running cash position at
/// the end of `date`'s bucket). `date` is the bucket anchor — a day for daily
/// granularity, the first of the month for monthly — and drives a real Date
/// x-axis so the chart auto-spaces and thins its labels.
struct CashFlowSeriesPoint: Identifiable, Sendable {
    let id = UUID()
    let date: Date        // bucket anchor (day, or 1st-of-month)
    let balance: Double   // cumulative cash on hand
}

/// Bucket size of the cash-flow chart series, which drives the x-axis date
/// format (daily → `1 Jun`, monthly → `Jun`).
enum CashFlowGranularity: Sendable {
    case daily, monthly
}

/// Profit & loss panel (Laba Rugi): revenue, expenses, net profit + trend.
struct ProfitLossSummary: Sendable {
    let revenue: Double
    let expenses: Double
    let profit: Double
    let changePercentage: Double
    let trend: String   // "up" | "down" | "flat"
}

/// Cash movement panel (Arus Kas): receipts, disbursements, net increase.
struct CashFlowMovement: Sendable {
    let receipt: Double
    let disbursement: Double
    let cashIncrease: Double
    let changePercentage: Double
    let trend: String
}

// MARK: - Top Expenses (dashboard breakdown)

/// One category slice in the Top Expenses breakdown.
struct ExpenseBreakdown: Identifiable, Sendable {
    let id = UUID()
    let category: String
    let amount: Double
    let color: ExpenseBreakdownColor
}

/// Palette index for an expense breakdown slice (the proportion bar and the
/// list bullet share this tint).
enum ExpenseBreakdownColor: Sendable, CaseIterable {
    case blue, teal, orange, purple, pink, gray
}

/// A shortcut tile in the dashboard's "Quick Create" grid. Tapping it switches
/// the root tab bar to `destination`.
struct QuickAction: Identifiable, Sendable {
    let id = UUID()
    let title: String
    let systemImage: String
    let tint: QuickActionTint
    let destination: MainTab
}

enum QuickActionTint: Sendable {
    case accent, income, expense, neutral
}
