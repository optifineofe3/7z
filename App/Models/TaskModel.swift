//
//  TaskModel.swift
//  7Zip Operation Task Model
//

import Foundation

public enum TaskType: String, Codable {
    case compress = "compress"
    case extract = "extract"
    case test = "test"
    case delete = "delete"
    case hash = "hash"
    case benchmark = "benchmark"

    public var iconName: String {
        switch self {
        case .compress: return "archivebox.fill"
        case .extract: return "tray.and.arrow.down.fill"
        case .test: return "checkmark.shield.fill"
        case .delete: return "trash.fill"
        case .hash: return "number.square.fill"
        case .benchmark: return "speedometer"
        }
    }
}

public enum TaskStatus: String, Codable {
    case queued = "queued"
    case running = "running"
    case completed = "completed"
    case failed = "failed"
    case cancelled = "cancelled"

    public var localizedName: String {
        switch self {
        case .queued: return NSLocalizedString("task_queued", comment: "")
        case .running: return NSLocalizedString("task_active", comment: "")
        case .completed: return NSLocalizedString("task_completed", comment: "")
        case .failed: return NSLocalizedString("task_failed", comment: "")
        case .cancelled: return NSLocalizedString("task_cancelled", comment: "")
        }
    }
}

public struct OperationTask: Identifiable, ObservableObject {
    public let id = UUID()
    public var type: TaskType
    public var title: String
    public var commandLine: [String]

    @Published public var status: TaskStatus = .queued
    @Published public var progress: Double = 0.0 // 0..100
    @Published public var speedBytesPerSec: Double = 0.0
    @Published public var remainingSeconds: Double = 0.0
    @Published public var currentFile: String = ""
    @Published public var logs: [String] = []
    @Published public var exitCode: Int? = nil
    @Published public var errorMessage: String? = nil

    public var startedAt: Date = Date()
    public var finishedAt: Date? = nil

    public init(type: TaskType, title: String, commandLine: [String]) {
        self.type = type
        self.title = title
        self.commandLine = commandLine
    }

    public var formattedSpeed: String {
        guard speedBytesPerSec > 0 else { return "--" }
        return ByteCountFormatter.string(fromByteCount: Int64(speedBytesPerSec), countStyle: .binary) + "/s"
    }

    public var formattedETA: String {
        guard remainingSeconds > 0 else { return "--" }
        let sec = Int(remainingSeconds)
        if sec < 60 {
            return "\(sec)s"
        } else {
            return String(format: "%d:%02d", sec / 60, sec % 60)
        }
    }
}
