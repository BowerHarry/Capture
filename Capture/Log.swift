import Foundation
import os

/// Minimal logging wrapper. Messages are marked private so that identifiers and
/// server responses are redacted in logs collected outside a debugger.
enum Log {
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "Capture", category: "app")

    static func error(_ message: String) {
        logger.error("\(message, privacy: .private)")
    }
}
