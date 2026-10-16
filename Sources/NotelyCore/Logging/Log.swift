import Foundation

public enum LogLevel: Int, Comparable, CustomStringConvertible {
    case debug, info, warning, error

    public static func < (lhs: LogLevel, rhs: LogLevel) -> Bool { lhs.rawValue < rhs.rawValue }

    public var description: String {
        switch self {
        case .debug: "debug"
        case .info: "info"
        case .warning: "warning"
        case .error: "error"
        }
    }

    init?(name: String) {
        switch name.lowercased() {
        case "debug": self = .debug
        case "info": self = .info
        case "warning", "warn": self = .warning
        case "error": self = .error
        default: return nil
        }
    }
}

/// Writes one line per message to standard error, so a terminal shows it
/// when the app is started from there (`just dev`). Messages below the
/// minimum level are dropped without building their text.
///
/// The minimum level is `info`, or the value of the `NOTELY_LOG_LEVEL`
/// environment variable (`debug`, `info`, `warning`, `error`).
public struct Log {
    /// The level read from `NOTELY_LOG_LEVEL`, once per launch.
    public static let minimumLevel: LogLevel = {
        ProcessInfo.processInfo.environment["NOTELY_LOG_LEVEL"].flatMap(LogLevel.init(name:)) ?? .info
    }()

    /// Names the part of the app a line comes from, such as `sqlite`.
    public let category: String

    public init(_ category: String) {
        self.category = category
    }

    public func debug(_ message: @autoclosure () -> String) { write(.debug, message) }
    public func info(_ message: @autoclosure () -> String) { write(.info, message) }
    public func warning(_ message: @autoclosure () -> String) { write(.warning, message) }
    public func error(_ message: @autoclosure () -> String) { write(.error, message) }

    private func write(_ level: LogLevel, _ message: () -> String) {
        guard level >= Self.minimumLevel else { return }
        let time = Date.now.formatted(.iso8601.time(includingFractionalSeconds: true))
        FileHandle.standardError.write(Data("\(time) [\(level)] [\(category)] \(message())\n".utf8))
    }
}
