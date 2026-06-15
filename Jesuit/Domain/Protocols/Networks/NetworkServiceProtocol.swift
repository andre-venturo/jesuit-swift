//
//  NetworkServiceProtocol.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import Foundation

protocol NetworkServiceProtocol: Actor {
    func request<T: Codable & Sendable, Body: Encodable & Sendable>(
        endpoint: Endpoint,
        body: Body?,
        responseType: T.Type
    ) async throws -> APIResponse<T>?

    /// Decodes the response body directly into `T` (no `APIResponse` wrapper),
    /// for endpoints whose envelope differs from the core API.
    func requestDecoded<T: Codable & Sendable, Body: Encodable & Sendable>(
        endpoint: Endpoint,
        body: Body?,
        responseType: T.Type
    ) async throws -> T
}

// protocol NetworkServiceProtocol {
//    func request<T: Codable>(
//        endpoint: Endpoint,
//        responseType: T.Type
//    ) async throws -> APIResponse<T>
//
////    func requestWithoutResponse(
////        endpoint: Endpoint
////    ) async throws
// }
