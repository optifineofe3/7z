//
//  TaskManager.swift
//  7Zip Background Task Queue & Execution Manager
//

import Foundation
import UIKit
import UserNotifications

public final class TaskManager: ObservableObject {
    public static let shared = TaskManager()

    @Published public var tasks: [OperationTask] = []
    @Published public var currentActiveTask: OperationTask? = nil

    private var backgroundTaskId: UIBackgroundTaskIdentifier = .invalid
    private let queue = DispatchQueue(label: "com.sevenzip.taskqueue", qos: .userInitiated)

    private init() {
        requestNotificationPermission()
    }

    public func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    public func enqueue(task: OperationTask) {
        DispatchQueue.main.async {
            self.tasks.append(task)
            self.processNextTask()
        }
    }

    public func cancelTask(_ task: OperationTask) {
        if currentActiveTask?.id == task.id {
            SevenZipBridge.shared.cancel()
            DispatchQueue.main.async {
                task.status = .cancelled
            }
        } else if task.status == .queued {
            DispatchQueue.main.async {
                task.status = .cancelled
            }
        }
    }

    public func retryTask(_ task: OperationTask) {
        DispatchQueue.main.async {
            task.status = .queued
            task.progress = 0.0
            task.logs.removeAll()
            task.errorMessage = nil
            task.exitCode = nil
            self.processNextTask()
        }
    }

    public func clearFinished() {
        DispatchQueue.main.async {
            self.tasks.removeAll { $0.status == .completed || $0.status == .cancelled || $0.status == .failed }
        }
    }

    private func processNextTask() {
        guard currentActiveTask == nil else { return }
        guard let next = tasks.first(where: { $0.status == .queued }) else { return }

        currentActiveTask = next
        next.status = .running
        next.startedAt = Date()

        // Section 3.6: Begin background task & disable idle timer
        DispatchQueue.main.async {
            UIApplication.shared.isIdleTimerDisabled = true
        }

        backgroundTaskId = UIApplication.shared.beginBackgroundTask(withName: "7ZipTask-\(next.title)") {
            self.endBackgroundTask()
        }

        SevenZipBridge.shared.execute(
            arguments: next.commandLine,
            onProgress: { info in
                DispatchQueue.main.async {
                    next.progress = info.percent
                    next.speedBytesPerSec = info.speed_bytes_per_sec
                    next.remainingSeconds = info.remaining_seconds
                    if let f = info.current_file {
                        next.currentFile = String(cString: f)
                    }
                }
            },
            onLog: { line in
                DispatchQueue.main.async {
                    next.logs.append(line)
                }
            },
            onError: { msg, isWarn in
                DispatchQueue.main.async {
                    next.logs.append("[ERROR] \(msg)")
                    if !isWarn {
                        next.errorMessage = msg
                    }
                }
            },
            completion: { [weak self] exitCode in
                guard let self = self else { return }
                DispatchQueue.main.async {
                    next.exitCode = exitCode
                    next.finishedAt = Date()

                    if exitCode == SZ_OK || exitCode == SZ_WARNING {
                        next.status = .completed
                        next.progress = 100.0
                        AppTheme.triggerHaptic(type: .success)
                        self.sendNotification(title: "7-Zip", body: "\(next.title) completed successfully.")
                    } else if exitCode == SZ_USER_STOPPED {
                        next.status = .cancelled
                    } else {
                        next.status = .failed
                        AppTheme.triggerHaptic(type: .error)
                        let isRu = Locale.current.languageCode == "ru"
                        let errText = SevenZipBridge.shared.errorMessage(for: exitCode, isRussian: isRu)
                        next.errorMessage = errText
                        self.sendNotification(title: "7-Zip Error", body: "\(next.title): \(errText)")
                    }

                    self.currentActiveTask = nil
                    self.endBackgroundTask()
                    self.processNextTask()
                }
            }
        )
    }

    private func endBackgroundTask() {
        DispatchQueue.main.async {
            if self.currentActiveTask == nil {
                UIApplication.shared.isIdleTimerDisabled = false
            }
        }
        if backgroundTaskId != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTaskId)
            backgroundTaskId = .invalid
        }
    }

    private func sendNotification(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }
}
