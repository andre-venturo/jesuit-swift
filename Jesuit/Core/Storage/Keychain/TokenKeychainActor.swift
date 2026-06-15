//
//  TokenKeychainActor.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import Foundation
import Security

actor TokenKeychainActor {
    static let shared = TokenKeychainActor()

    let accessKey = "auth_access_token"
    let refreshKey = "auth_refresh_token"
    let service = Bundle.main.bundleIdentifier ?? "app.keychain.default"

    func setTokens(accessToken: String, refreshToken: String) throws {
        try setString(accessToken, forKey: accessKey)
        try setString(refreshToken, forKey: refreshKey)
    }

    func getTokens() throws -> (access: String, refresh: String)? {
        guard let access = try getString(forKey: accessKey),
              let refresh = try getString(forKey: refreshKey) else {
            return nil
        }
        return (access, refresh)
    }

    func clear() throws {
        try removeString(forKey: accessKey)
        try removeString(forKey: refreshKey)
    }
}
