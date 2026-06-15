//
//  NetworkError.swift
//  Jesuit
//
//  Created by admin on 22/11/25.
//

import Foundation

enum NetworkError: Error {
    case invalidURL
    case noData
    case decodingError(String)
    case serverError(Int, String?)
    case unauthorized
    case networkFailure(String)
    case unknown

    var localizedDescription: String {
        switch self {
        case .invalidURL:
            return "Invalid URL"
        case .noData:
            return "No data received"
        case .decodingError(let message):
            return "Failed to decode: \(message)"
        case .serverError(let code, let message):
            return "Server error (\(code)): \(message ?? "Unknown error")"
        case .unauthorized:
            return "Unauthorized access"
        case .networkFailure(let message):
            return "Network failure: \(message)"
        case .unknown:
            return "Unknown error occurred"
        }
    }
}
