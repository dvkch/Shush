//
//  Loggable.swift
//  Shush
//
//  Created by syan on 26/04/2024.
//  Copyright © 2024 Syan. All rights reserved.
//

import Foundation
import os

internal protocol Loggable {
    var logTag: String { get }
}

private class LogClass {}

internal enum LogLevel {
    case debug
    case info
    case warn
    case error
    
    var name: String {
        switch self {
        case .debug: return "D"
        case .info:  return "I"
        case .warn:  return "W"
        case .error: return "E"
        }
    }
    
    #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
    var osLogType: OSLogType {
        switch self {
        case .debug: return .debug
        case .info:  return .info
        case .warn:  return .default
        case .error: return .error
        }
    }
    #endif
}

internal extension Loggable {
    func log(_ level: LogLevel = .info, _ message: String) {
        #if os(macOS) || os(iOS) || os(tvOS) || os(watchOS)
        let osLog = OSLog(subsystem: Bundle(for: LogClass.self).bundleIdentifier ?? "<Unknown>", category: logTag)
        os_log(level.osLogType, log: osLog, "%@", message)
        #else
        print("\(level.name): \(tag) - \(message)")
        #endif
    }
}
