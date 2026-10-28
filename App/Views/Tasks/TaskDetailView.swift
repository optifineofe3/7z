//
//  TaskDetailView.swift
//  7Zip Operation Task Details & Console Log Viewer
//

import SwiftUI
import UIKit

public struct TaskDetailView: View {
    @ObservedObject public var task: OperationTask
    @State private var copied: Bool = false

    public init(task: OperationTask) {
        self.task = task
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Status card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Image(systemName: task.type.iconName)
                            .font(.system(size: 24))
                            .foregroundColor(AppTheme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(task.title)
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            Text(task.status.localizedName)
                                .font(.caption)
                                .foregroundColor(statusColor)
                        }
                        Spacer()
                    }

                    if task.status == .running {
                        VStack(alignment: .leading, spacing: 6) {
                            ProgressView(value: task.progress, total: 100.0)
                                .tint(AppTheme.accent)
                            HStack {
                                Text("\(Int(task.progress))%")
                                Spacer()
                                Text(task.formattedSpeed)
                                Text("•")
                                Text("ETA: \(task.formattedETA)")
                            }
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)

                            if !task.currentFile.isEmpty {
                                Text(task.currentFile)
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                    } else if let code = task.exitCode {
                        Text("Exit code: \(code)")
                            .font(.caption)
                            .foregroundColor(code == 0 ? AppTheme.success : AppTheme.error)
                    }

                    if let err = task.errorMessage {
                        Text(err)
                            .font(.caption)
                            .foregroundColor(AppTheme.error)
                    }
                }
                .appCardStyle()

                // Command Line card
                VStack(alignment: .leading, spacing: 6) {
                    Text("Command Line")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Text(task.sanitizedCommandLine)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(AppTheme.textPrimary)
                }
                .appCardStyle()

                // Console Logs card
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(NSLocalizedString("task_logs", comment: ""))
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)
                        Spacer()
                        Button(action: copyLog) {
                            HStack(spacing: 4) {
                                Image(systemName: copied ? "checkmark" : "doc.on.doc")
                                Text(copied ? "Copied" : NSLocalizedString("copy_log", comment: ""))
                            }
                            .font(.caption)
                            .foregroundColor(AppTheme.accent)
                        }
                    }

                    if task.logs.isEmpty {
                        Text("No log messages")
                            .font(.caption)
                            .foregroundColor(AppTheme.textSecondary)
                            .padding(.vertical, 8)
                    } else {
                        ScrollView(.horizontal) {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(task.logs.enumerated()), id: \.offset) { _, line in
                                    Text(line)
                                        .font(.system(size: 11, design: .monospaced))
                                        .foregroundColor(line.starts(with: "[ERROR]") ? AppTheme.error : AppTheme.textPrimary)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .appCardStyle()
            }
            .padding(16)
        }
        .appBackground()
        .navigationTitle(task.title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var statusColor: Color {
        switch task.status {
        case .running: return AppTheme.accent
        case .completed: return AppTheme.success
        case .failed: return AppTheme.error
        case .cancelled: return AppTheme.warning
        case .queued: return AppTheme.textSecondary
        }
    }

    private func copyLog() {
        let full = task.logs.joined(separator: "\n")
        UIPasteboard.general.string = full
        AppTheme.triggerImpact(style: .light)
        copied = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            copied = false
        }
    }
}
