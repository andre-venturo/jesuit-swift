//
//  Endpoint.swift
//  Jesuit
//
//  Created by admin on 23/11/25.
//

import Foundation

struct Endpoint: Sendable {
    let path: String?
    let method: HTTPMethod
    let headers: [String: String]?
    let parameters: [String: String]?
    let requiresAuth: Bool
    let baseURL: String
    let url: String

    init(
        baseURL: String? = nil,
        path: String?,
        method: HTTPMethod = .get,
        headers: [String: String]? = ["Content-Type": "application/json"],
        parameters: [String: String]? = nil,
        requiresAuth: Bool = true
    ) {
        self.path = path
        self.method = method
        self.headers = headers
        self.parameters = parameters
        self.requiresAuth = requiresAuth
        let baseUrl = baseURL ?? AppURLConstants.baseURL
        self.baseURL = baseUrl
        self.url = "\(baseUrl)\(path ?? "")"
    }
}
