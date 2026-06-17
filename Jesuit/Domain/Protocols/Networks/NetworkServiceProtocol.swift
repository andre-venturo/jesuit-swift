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

    /// Sends a `multipart/form-data` request — named text fields plus file parts
    /// (e.g. the cash-transaction `submit` payload: a `data` JSON field and
    /// `attachments_n` files) — and decodes the body directly into `T`.
    func requestMultipartDecoded<T: Codable & Sendable>(
        endpoint: Endpoint,
        textFields: [MultipartTextField],
        files: [MultipartFile],
        responseType: T.Type
    ) async throws -> T
}

/// A named text field in a multipart body (e.g. `data` carrying the JSON payload).
struct MultipartTextField: Sendable {
    let name: String
    let value: String
}

/// A named file part in a multipart body.
struct MultipartFile: Sendable {
    let field: String      // form field name, e.g. "attachments_0"
    let filename: String
    let mimeType: String
    let data: Data
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
