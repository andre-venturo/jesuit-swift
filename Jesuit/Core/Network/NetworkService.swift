//
//  NetworkService.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import Foundation

actor NetworkService: NetworkServiceProtocol {
    static let shared = NetworkService()

    private let session: URLSession
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 10
        config.timeoutIntervalForResource = 20
        session = URLSession(configuration: config)
        decoder = JSONDecoder()
    }

    func request<T: Codable & Sendable, Body: Encodable & Sendable>(
        endpoint: Endpoint,
        body: Body? = nil,
        responseType: T.Type
    ) async throws -> APIResponse<T>? {
        let tokens = try? await TokenKeychainActor.shared.getTokens()
        let accessToken = tokens?.access

        let urlRequest = try buildRequest(from: endpoint, body: body, accessToken: accessToken)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try? decoder.decode(APIResponse<T>?.self, from: data)
        case 401:
            throw NetworkError.unauthorized
        case 400...499:
            let errorMessage = try? decoder.decode(APIResponse<T>?.self, from: data)?.message
            let fixMessage = errorMessage ?? NetworkError.unknown.localizedDescription

            throw NetworkError.serverError(httpResponse.statusCode, fixMessage)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode, "Server error")
        default:
            throw NetworkError.unknown
        }
    }

    /// Decodes the response body directly into `T`, without the core
    /// `APIResponse` wrapper. Used by endpoints (e.g. finance) whose envelope
    /// differs (`{ data, message, meta }`).
    func requestDecoded<T: Codable & Sendable, Body: Encodable & Sendable>(
        endpoint: Endpoint,
        body: Body? = nil,
        responseType: T.Type
    ) async throws -> T {
        let tokens = try? await TokenKeychainActor.shared.getTokens()
        let accessToken = tokens?.access

        let urlRequest = try buildRequest(from: endpoint, body: body, accessToken: accessToken)

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NetworkError.unknown
        }

        switch httpResponse.statusCode {
        case 200...299:
            do {
                return try decoder.decode(T.self, from: data)
            } catch {
                throw NetworkError.decodingError(error.localizedDescription)
            }
        case 401:
            throw NetworkError.unauthorized
        case 400...499:
            let message = try? decoder.decode(APIResponse<EmptyResponse>?.self, from: data)?.message
            throw NetworkError.serverError(httpResponse.statusCode, message)
        case 500...599:
            throw NetworkError.serverError(httpResponse.statusCode, "Server error")
        default:
            throw NetworkError.unknown
        }
    }

    private func buildRequest<Body: Encodable & Sendable>(
        from endpoint: Endpoint,
        body: Body?,
        accessToken: String?
    ) throws -> URLRequest {
        guard var url = URL(string: endpoint.url) else { throw NetworkError.invalidURL }

        if let params = endpoint.parameters, endpoint.method == .get {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
            components?.queryItems = params.map { URLQueryItem(name: $0.key, value: $0.value) }
            if let urlWithQuery = components?.url { url = urlWithQuery }
        }

        var request = URLRequest(url: url)
        request.httpMethod = endpoint.method.rawValue

        var headers = endpoint.headers ?? [:]
        if let token = accessToken, endpoint.requiresAuth {
            headers["Authorization"] = "Bearer \(token)"
        }
        headers.forEach { request.setValue($0.value, forHTTPHeaderField: $0.key) }

        if let body = body, endpoint.method != .get {
            let encoder = JSONEncoder()
            request.httpBody = try encoder.encode(body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        } else if let params = endpoint.parameters, endpoint.method != .get {
            request.httpBody = try JSONSerialization.data(withJSONObject: params)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }

        return request
    }
}
