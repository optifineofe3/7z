//
//  TasksView.swift
//  7Zip Operation Tasks Queue & Active Progress View
//

import SwiftUI

public struct TasksView: View {
    @ObservedObject private var taskManager = TaskManager.shared

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Active running task banner if any
                    if let active = taskManager.currentActiveTask {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Image(systemName: active.type.iconName)
                                    .font(.system(size: 22))
                                    .foregroundColor(AppTheme.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(active.title)
                                        .font(.headline)
                                        .foregroundColor(AppTheme.textPrimary)
                                    Text("Active operation...")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.textSecondary)
                                }
                                Spacer()
                                Button(action: { taskManager.cancelTask(active) }) {
                                    Text(NSLocalizedString("btn_cancel_task", comment: ""))
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(AppTheme.error)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(AppTheme.divider)
                                        .cornerRadius(8)
                                }
                            }

                            // Progress Indicator
                            ProgressView(value: active.progress, total: 100.0)
                                .tint(AppTheme.accent)

                            HStack {
                                Text("\(Int(active.progress))%")
                                Spacer()
                                Text(active.formattedSpeed)
                                Text("•")
                                Text("ETA: \(active.formattedETA)")
                            }
                            .font(.caption2)
                            .foregroundColor(AppTheme.textSecondary)

                            if !active.currentFile.isEmpty {
                                Text(active.currentFile)
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                        }
                        .appCardStyle()
                        .padding(.horizontal, 16)
                    }

                    // Task List
                    if taskManager.tasks.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "checklist")
                                .font(.system(size: 40))
                                .foregroundColor(AppTheme.textSecondary)
                            Text("No active or queued tasks")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 48)
                        .appCardStyle()
                        .padding(.horizontal, 16)
                    } else {
                        VStack(spacing: 1) {
                            ForEach(taskManager.tasks) { task in
                                NavigationLink(destination: TaskDetailView(task: task)) {
                                    HStack(spacing: 12) {
                                        Image(systemName: task.type.iconName)
                                            .font(.system(size: 20))
                                            .foregroundColor(statusColor(for: task.status))

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(task.title)
                                                .font(.body)
                                                .foregroundColor(AppTheme.textPrimary)
                                                .lineLimit(1)
                                            Text(task.status.localizedName)
                                                .font(.caption2)
                                                .foregroundColor(AppTheme.textSecondary)
                                        }

                                        Spacer()

                                        if task.status == .failed {
                                            Button("Retry") {
                                                taskManager.retryTask(task)
                                            }
                                            .font(.caption)
                                            .foregroundColor(AppTheme.accent)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(AppTheme.divider)
                                            .cornerRadius(6)
                                        }

                                        Image(systemName: "chevron.right")
                                            .font(.caption)
                                            .foregroundColor(AppTheme.divider)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(AppTheme.cardBackground)
                                }
                                if task.id != taskManager.tasks.last?.id {
                                    Divider().background(AppTheme.divider)
                                }
                            }
                        }
                        .cornerRadius(AppTheme.cornerRadius)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                .stroke(AppTheme.divider, lineWidth: 1)
                        )
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.vertical, 16)
            }
            .appBackground()
            .navigationTitle(NSLocalizedString("tasks_title", comment: ""))
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    if !taskManager.tasks.isEmpty {
                        Button(NSLocalizedString("clear_tasks", comment: "")) {
                            taskManager.clearFinished()
                        }
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }

    private func statusColor(for status: TaskStatus) -> Color {
        switch status {
        case .running: return AppTheme.accent
        case .completed: return AppTheme.success
        case .failed: return AppTheme.error
        case .cancelled: return AppTheme.warning
        case .queued: return AppTheme.textSecondary
        }
    }
}
