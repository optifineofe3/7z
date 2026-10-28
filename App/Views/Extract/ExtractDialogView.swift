//
//  ExtractDialogView.swift
//  7Zip Archive Extraction Dialog
//

import SwiftUI
import UniformTypeIdentifiers

public struct ExtractDialogView: View {
    public let archiveURL: URL
    public let selectedItems: [ArchiveItem]
    public var onStarted: (() -> Void)?

    @Environment(\.dismiss) private var dismiss
    @State private var destinationURL: URL
    @State private var preserveFullPaths: Bool = true
    @State private var overwritePolicy: Int = 0 // 0 = Ask, 1 = Overwrite all, 2 = Skip, 3 = Auto-rename
    @State private var password: String = ""
    @State private var showFolderPicker: Bool = false

    public init(archiveURL: URL, selectedItems: [ArchiveItem] = [], onStarted: (() -> Void)? = nil) {
        self.archiveURL = archiveURL
        self.selectedItems = selectedItems
        self.onStarted = onStarted

        // Default destination: Documents directory
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let folderName = archiveURL.deletingPathExtension().lastPathComponent
        _destinationURL = State(initialValue: docs.appendingPathComponent(folderName, isDirectory: true))
    }

    public var body: some View {
        NavigationView {
            Form {
                // Section: Destination
                Section(header: Text(NSLocalizedString("destination_folder", comment: "")).foregroundColor(AppTheme.textSecondary)) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(destinationURL.lastPathComponent)
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            Text(destinationURL.path)
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                        Spacer()
                        Button(action: { showFolderPicker = true }) {
                            Text(NSLocalizedString("choose_folder", comment: ""))
                                .font(.subheadline)
                                .foregroundColor(AppTheme.accent)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(AppTheme.divider)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AppTheme.cardBackground)

                // Section: Options
                Section(header: Text("Options").foregroundColor(AppTheme.textSecondary)) {
                    Toggle(NSLocalizedString("extract_full_paths", comment: ""), isOn: $preserveFullPaths)
                        .tint(AppTheme.accent)

                    Picker(NSLocalizedString("overwrite_policy", comment: ""), selection: $overwritePolicy) {
                        Text(NSLocalizedString("overwrite_ask", comment: "")).tag(0)
                        Text(NSLocalizedString("overwrite_replace", comment: "")).tag(1)
                        Text(NSLocalizedString("overwrite_skip", comment: "")).tag(2)
                        Text(NSLocalizedString("overwrite_rename", comment: "")).tag(3)
                    }
                    .foregroundColor(AppTheme.textPrimary)

                    if !selectedItems.isEmpty {
                        HStack {
                            Text("Extracting Selected Items")
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("\(selectedItems.count) files")
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                }
                .listRowBackground(AppTheme.cardBackground)

                // Section: Password
                Section(header: Text(NSLocalizedString("section_encryption", comment: "")).foregroundColor(AppTheme.textSecondary)) {
                    SecureField(NSLocalizedString("password", comment: ""), text: $password)
                        .foregroundColor(AppTheme.textPrimary)
                }
                .listRowBackground(AppTheme.cardBackground)
            }
            .hideScrollContentBackground()
            .appBackground()
            .navigationTitle(NSLocalizedString("extract_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("btn_cancel", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startExtraction) {
                        Text(NSLocalizedString("btn_extract", comment: ""))
                            .bold()
                            .foregroundColor(AppTheme.background)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(AppTheme.accent)
                            .cornerRadius(12)
                    }
                }
            }
            .sheet(isPresented: $showFolderPicker) {
                DocumentPicker(mode: .openFolder { selectedFolder in
                    destinationURL = selectedFolder
                })
            }
        }
        .preferredColorScheme(.dark)
    }

    private func startExtraction() {
        let receipt = BookmarkManager.shared.prepareReadableURL(for: archiveURL)

        // Create destination directory if not exists
        try? FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let cmd = preserveFullPaths ? "x" : "e"
        var args = ["7zz", cmd, receipt.url.path, "-o\(destinationURL.path)"]

        // Overwrite switch
        switch overwritePolicy {
        case 1: args.append("-aoa")
        case 2: args.append("-aos")
        case 3: args.append("-aou")
        default: break // interactive / ask
        }

        // Password
        if !password.isEmpty {
            args.append("-p\(password)")
        }

        // Selected files only
        if !selectedItems.isEmpty {
            for item in selectedItems {
                args.append(item.path)
            }
        }

        args.append("-y")

        let taskTitle = "Extract: \(archiveURL.lastPathComponent)"
        let task = OperationTask(type: .extract, title: taskTitle, commandLine: args)
        task.securityScopedURLs.append(archiveURL)
        task.securityScopedURLs.append(destinationURL)
        if receipt.url != archiveURL {
            task.securityScopedURLs.append(receipt.url)
        }
        task.cleanupHandlers.append(receipt.cleanup)
        TaskManager.shared.enqueue(task: task)

        onStarted?()
        dismiss()
    }
}
