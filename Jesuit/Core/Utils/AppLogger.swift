//
//  AppLogger.swift
//  Jesuit
//
//  Structured logging facade over Apple's unified logging system, adopted from
//  the draft-core-v1 skeleton.
//

import Foundation
import OSLog

/// Structured logger using Apple's unified logging system.
nonisolated enum AppLogger {

    private static let subsystem = Bundle.main.bundleIdentifier ?? "com.jesuit"

    private static let general = Logger(subsystem: subsystem, category: "General")
    private static let network = Logger(subsystem: subsystem, category: "Network")
    private static let storage = Logger(subsystem: subsystem, category: "Storage")
    private static let auth    = Logger(subsystem: subsystem, category: "Auth")

    static func debug(_ message: String, category: LogCategory = .general) {
        logger(for: category).debug("\(message, privacy: .public)")
    }

    static func info(_ message: String, category: LogCategory = .general) {
        logger(for: category).info("\(message, privacy: .public)")
    }

    static func warning(_ message: String, category: LogCategory = .general) {
        logger(for: category).warning("\(message, privacy: .public)")
    }

    static func error(_ message: String, error: Error? = nil, category: LogCategory = .general) {
        if let error {
            logger(for: category).error("\(message, privacy: .public): \(error.localizedDescription, privacy: .public)")
        } else {
            logger(for: category).error("\(message, privacy: .public)")
        }
    }

    private static func logger(for category: LogCategory) -> Logger {
        switch category {
        case .general: return general
        case .network: return network
        case .storage: return storage
        case .auth:    return auth
        }
    }

    enum LogCategory {
        case general, network, storage, auth
    }
}
