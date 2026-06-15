//
//  DashboardRepository.swift
//  Jesuit
//
//  Concrete implementation of the finance dashboard endpoints backing the home
//  Cash Flow card (daily-revenue + profit-loss-cash-flow).
//

import Foundation

struct DashboardRepository: DashboardRepositoryProtocol {
    private let network: NetworkServiceProtocol

    init(network: NetworkServiceProtocol) {
        self.network = network
    }

    func fetchCashFlow(startDate: Date, endDate: Date) async throws -> DashboardCashFlow {
        let start = Self.apiDate(startDate)
        let end = Self.apiDate(endDate)

        async let revenueResult = fetchDailyRevenue(start: start, end: end)
        async let summaryResult = fetchProfitLossCashFlow(start: start, end: end)
        let series = try await revenueResult
        let summary = try await summaryResult

        return Self.build(series: series, summary: summary,
                          startDate: startDate, endDate: endDate)
    }

    // MARK: - Requests

    private func fetchDailyRevenue(start: String, end: String) async throws -> [DailyRevenueDTO] {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.dashboardDailyRevenue,
            method: .get,
            parameters: ["start_date": start, "end_date": end]
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: DailyRevenueResponse.self
        )
        return response.data?.series ?? []
    }

    func fetchCashAccounts() async throws -> CashAccounts {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.dashboardCashAccounts,
            method: .get
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: CashAccountsResponse.self
        )
        let accounts: [CashAccount] = (response.data?.accounts ?? []).compactMap { dto in
            guard let id = dto.accountId else { return nil }
            return CashAccount(
                id: id,
                name: (dto.accountName ?? "").trimmingCharacters(in: .whitespaces),
                balance: dto.balance ?? 0
            )
        }
        return CashAccounts(totalBalance: response.data?.totalBalance ?? 0, accounts: accounts)
    }

    private func fetchProfitLossCashFlow(start: String, end: String) async throws -> ProfitLossCashFlowResponse.Payload? {
        let endpoint = Endpoint(
            baseURL: AppURLConstants.financeBaseURL,
            path: AppURLConstants.Finance.dashboardProfitLossCashFlow,
            method: .get,
            parameters: ["start_date": start, "end_date": end]
        )
        let response = try await network.requestDecoded(
            endpoint: endpoint,
            body: Optional<EmptyResponse>.none,
            responseType: ProfitLossCashFlowResponse.self
        )
        return response.data
    }

    // MARK: - Mapping

    /// Builds the cumulative cash-balance chart series plus the Laba Rugi /
    /// Arus Kas summary panels. The chart line is the running sum of
    /// `revenue - expense` (opening cash = 0). Buckets are daily for short
    /// ranges (≤ ~2 months) and monthly otherwise, so the axis stays readable.
    static func build(
        series: [DailyRevenueDTO],
        summary: ProfitLossCashFlowResponse.Payload?,
        startDate: Date,
        endDate: Date
    ) -> DashboardCashFlow {
        let calendar = Calendar.current
        let spanDays = (calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0)
        let byMonth = spanDays > 62

        struct Bucket { var anchor: Date; var net: Double }
        var buckets: [Date: Bucket] = [:]
        for day in series {
            guard let date = day.date else { continue }
            let key = byMonth
                ? (calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date)
                : calendar.startOfDay(for: date)
            let net = (day.revenue ?? 0) - (day.expense ?? 0)
            buckets[key, default: Bucket(anchor: key, net: 0)].net += net
        }

        var running = 0.0
        let points: [CashFlowSeriesPoint] = buckets.values
            .sorted { $0.anchor < $1.anchor }
            .map { bucket in
                running += bucket.net
                let label = byMonth ? monthLabel(bucket.anchor) : dayLabel(bucket.anchor)
                return CashFlowSeriesPoint(label: label, balance: running)
            }

        let pl = summary?.profitLoss
        let cf = summary?.cashFlow
        let profitLoss = ProfitLossSummary(
            revenue: pl?.revenue ?? 0,
            expenses: pl?.expenses ?? 0,
            profit: pl?.profit ?? 0,
            changePercentage: pl?.changePercentage ?? 0,
            trend: pl?.trend ?? "flat"
        )
        let cashFlow = CashFlowMovement(
            receipt: cf?.receiptJournal ?? 0,
            disbursement: cf?.disbursementJournal ?? 0,
            cashIncrease: cf?.cashIncrease ?? 0,
            changePercentage: cf?.changePercentage ?? 0,
            trend: cf?.trend ?? "flat"
        )

        return DashboardCashFlow(series: points, profitLoss: profitLoss, cashFlow: cashFlow)
    }

    // MARK: - Date helpers

    private static func apiDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }

    /// Short x-axis label for a month bucket, e.g. `Jan`.
    private static func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "MMM"
        return f.string(from: date)
    }

    /// Short x-axis label for a day bucket, e.g. `5`.
    private static func dayLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f.string(from: date)
    }
}
