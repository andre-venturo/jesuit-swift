//
//  AppError.swift
//  Jesuit
//
//  Typed, user-presentable error hierarchy adopted from the draft-core-v1
//  skeleton. Bridges the lower-level `NetworkError` into copy backed by
//  `AppStrings`.
//

import Foundation

/// Typed error hierarchy.
nonisolated enum AppError: LocalizedError, Equatable {

    case network
    case unauthorized
    case notFound
    case server(message: String, statusCode: Int?)
    case cache(message: String)
    case validation(message: String)
    case unknown

    var errorDescription: String? {
        switch self {
        case .network:                 return AppStrings.errorNetwork
        case .unauthorized:            return AppStrings.errorUnauthorized
        case .notFound:                return AppStrings.errorNotFound
        case .server(let message, _):  return message
        case .cache(let message):      return message
        case .validation(let message): return message
        case .unknown:                 return AppStrings.errorGeneric
        }
    }

    var statusCode: Int? {
        switch self {
        case .unauthorized:        return 401
        case .notFound:            return 404
        case .server(_, let code): return code
        default:                   return nil
        }
    }

    // MARK: - Conversion from HTTP status
    static func from(statusCode: Int, message: String = "") -> AppError {
        switch statusCode {
        case 401: return .unauthorized
        case 404: return .notFound
        default:  return .server(message: message.isEmpty ? AppStrings.errorServerError : message,
                                 statusCode: statusCode)
        }
    }

    // MARK: - Conversion from NetworkError
    /// Maps the transport-level `NetworkError` onto the presentable hierarchy.
    static func from(_ error: NetworkError) -> AppError {
        switch error {
        case .invalidURL, .networkFailure, .noData:
            return .network
        case .unauthorized:
            return .unauthorized
        case .serverError(let code, let message):
            return .from(statusCode: code, message: message ?? "")
        case .decodingError(let message):
            return .server(message: message, statusCode: nil)
        case .unknown:
            return .unknown
        }
    }
}
