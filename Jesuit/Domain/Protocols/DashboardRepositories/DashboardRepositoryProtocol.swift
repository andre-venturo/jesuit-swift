//
//  DashboardRepositoryProtocol.swift
//  Jesuit
//
//  Abstraction over the wizhub finance dashboard endpoints used by the home
//  Cash Flow card.
//

import Foundation

protocol DashboardRepositoryProtocol: Sendable {
    /// Loads the Cash Flow card for `[startDate, endDate]`: the daily-revenue
    /// series (chart) and the profit-loss/cash-flow summary (incoming/outgoing,
    /// net and trend).
    func fetchCashFlow(startDate: Date, endDate: Date) async throws -> DashboardCashFlow

    /// Loads the "Rekening Kas & Bank" card: per-account balances and the total.
    func fetchCashAccounts() async throws -> CashAccounts

    /// Loads the "Neraca" (balance sheet) card as of `date`: assets (Harta),
    /// liabilities (Kewajiban) and equity (Modal).
    func fetchBalanceSheet(asOf date: Date) async throws -> BalanceSheetSummary
}
