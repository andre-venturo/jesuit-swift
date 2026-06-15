//
//  DashboardCashFlowModels.swift
//  Jesuit
//
//  Domain entities + DTOs for the dashboard Cash Flow card, backed by two
//  finance endpoints:
//    GET /finance/v1/dashboard/daily-revenue        → the chart series
//    GET /finance/v1/dashboard/profit-loss-cash-flow → the summary + trend
//

import Foundation

// MARK: - Daily revenue (chart series)

/// One day's revenue/expense bucket from `daily-revenue.series`.
nonisolated struct DailyRevenueDTO: Codable, Sendable {
    let date: Date?
    let revenue: Double?
    let expense: Double?

    enum CodingKeys: String, CodingKey { case date, revenue, expense }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        revenue = try? c.decode(Double.self, forKey: .revenue)
        expense = try? c.decode(Double.self, forKey: .expense)
        if let str = try? c.decode(String.self, forKey: .date) {
            let f = DateFormatter()
            f.locale = Locale(identifier: "en_US_POSIX")
            f.dateFormat = "yyyy-MM-dd"
            date = f.date(from: str)
        } else {
            date = nil
        }
    }
}

nonisolated struct DailyRevenueResponse: Codable, Sendable {
    let data: Payload?
    nonisolated struct Payload: Codable, Sendable {
        let series: [DailyRevenueDTO]?
    }
}

// MARK: - Profit & loss / cash flow (summary)

/// The `cash_flow` block of `profit-loss-cash-flow`.
nonisolated struct CashFlowSummaryDTO: Codable, Sendable {
    let receiptJournal: Double?
    let disbursementJournal: Double?
    let cashIncrease: Double?
    let changePercentage: Double?
    let trend: String?

    enum CodingKeys: String, CodingKey {
        case trend
        case receiptJournal = "receipt_journal"
        case disbursementJournal = "disbursement_journal"
        case cashIncrease = "cash_increase"
        case changePercentage = "change_percentage"
    }
}

/// The `profit_loss` block of `profit-loss-cash-flow`.
nonisolated struct ProfitLossDTO: Codable, Sendable {
    let revenue: Double?
    let expenses: Double?
    let profit: Double?
    let changePercentage: Double?
    let trend: String?

    enum CodingKeys: String, CodingKey {
        case revenue, expenses, profit, trend
        case changePercentage = "change_percentage"
    }
}

nonisolated struct ProfitLossCashFlowResponse: Codable, Sendable {
    let data: Payload?
    nonisolated struct Payload: Codable, Sendable {
        let profitLoss: ProfitLossDTO?
        let cashFlow: CashFlowSummaryDTO?

        enum CodingKeys: String, CodingKey {
            case profitLoss = "profit_loss"
            case cashFlow = "cash_flow"
        }
    }
}

// MARK: - Cash & bank accounts (Rekening Kas & Bank)

/// One account row from `dashboard/cash-accounts.accounts`.
nonisolated struct CashAccountDTO: Codable, Sendable {
    let accountId: String?
    let accountCode: String?
    let accountName: String?
    let balance: Double?

    enum CodingKeys: String, CodingKey {
        case accountId = "account_id"
        case accountCode = "account_code"
        case accountName = "account_name"
        case balance
    }
}

nonisolated struct CashAccountsResponse: Codable, Sendable {
    let data: Payload?
    nonisolated struct Payload: Codable, Sendable {
        let totalBalance: Double?
        let accounts: [CashAccountDTO]?

        enum CodingKeys: String, CodingKey {
            case totalBalance = "total_balance"
            case accounts
        }
    }
}

/// One row in the dashboard "Rekening Kas & Bank" card.
struct CashAccount: Identifiable, Sendable {
    let id: String
    let name: String
    let balance: Double
}

/// The cash & bank accounts list plus its total balance.
struct CashAccounts: Sendable {
    let totalBalance: Double
    let accounts: [CashAccount]
}

// MARK: - UI aggregate

/// Everything the dashboard Cash Flow card needs for one period: the cumulative
/// balance chart series plus the Laba Rugi (profit/loss) and Arus Kas (cash
/// movement) summary panels.
struct DashboardCashFlow: Sendable {
    let series: [CashFlowSeriesPoint]
    let profitLoss: ProfitLossSummary
    let cashFlow: CashFlowMovement
    /// Bucket size of `series`, for the chart's x-axis date format.
    let granularity: CashFlowGranularity
}
