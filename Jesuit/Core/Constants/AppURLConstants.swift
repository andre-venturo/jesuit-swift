//
//  AppURLConstants.swift
//  Jesuit
//
//  Created by admin on 23/11/25.
//

import Foundation

enum AppURLConstants {
    static let baseURL: String = "https://api.wizhub.id/core/v1"
    static let financeBaseURL: String = "https://api.wizhub.id/finance/v1"

    enum Auth {
        static let signIn = "/auth/signin"
        static let signUp = "/auth/signup"
        static let logout = "/auth/logout"
        static let me = "/auth/me"
        static let companies = "/auth/companies"
        static let switchCompany = "/auth/switch-company"
    }

    enum Finance {
        static let contacts = "/contacts"
        static let contactCategories = "/contact-categories"

        /// `/contacts/{id}` — PUT update, DELETE.
        static func contact(_ id: String) -> String { "/contacts/\(id)" }
        static let cashTransactions = "/cash-transactions"
        static let cashTransactionsSubmit = "/cash-transactions/submit"
        static let accounts = "/accounts"
        static let dashboardDailyRevenue = "/dashboard/daily-revenue"
        static let dashboardProfitLossCashFlow = "/dashboard/profit-loss-cash-flow"
        static let dashboardCashAccounts = "/dashboard/cash-accounts"

        /// `/cash-transactions/{id}` — GET detail, PUT update, DELETE.
        static func cashTransaction(_ id: String) -> String { "/cash-transactions/\(id)" }
        static func cashTransactionApprove(_ id: String) -> String { "/cash-transactions/\(id)/approve" }
        static func cashTransactionReject(_ id: String) -> String { "/cash-transactions/\(id)/reject" }
    }

    enum Core {
        static let branches = "/branches"
        /// `POST /companies` — create a company (holding or subsidiary).
        static let companies = "/companies"
        /// `/companies/{id}` — PUT update, DELETE.
        static func company(_ id: String) -> String { "/companies/\(id)" }
    }
}
