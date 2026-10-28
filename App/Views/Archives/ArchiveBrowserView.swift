//
//  ArchiveBrowserView.swift
//  7Zip Archive Browser, Hierarchy Navigator & File Operations
//

import SwiftUI
import QuickLook

public struct ArchiveBrowserView: View {
    public let archiveURL: URL

    @State private var items: [ArchiveItem] = []
    @State private var archiveInfo = ArchiveInfo()
    @State private var isLoading: Bool = true
    @State private var errorMessage: String? = nil

    @State private var currentPrefix: String = "" // Folder path navigation
    @State private var searchText: String = ""
    @State private var sortOption: SortOption = .name
    @State private var isSelectMode: Bool = false
    @State private var selectedItemPaths: Set<String> = []

    // Sheets & Dialogs
    @State private var showInfoSheet: Bool = false
    @State private var showExtractSheet: Bool = false
    @State private var showShareSheet: Bool = false
    @State private var shareURL: URL? = nil

    // Quick Look preview state
    @State private var quickLookURL: URL? = nil
    @State private var isExtractingPreview: Bool = false

    // Password prompt state
    @State private var promptPassword: Bool = false
    @State private var enteredPassword: String = ""

    public enum SortOption: String, CaseIterable {
        case name = "Name"
        case size = "Size"
        case packedSize = "Packed Size"
        case date = "Date"
    }

    public init(archiveURL: URL) {
        self.archiveURL = archiveURL
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search & Sort bar
            HStack(spacing: 10) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(AppTheme.textSecondary)
                    TextField(NSLocalizedString("search_placeholder", comment: ""), text: $searchText)
                        .foregroundColor(AppTheme.textPrimary)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .padding(8)
                .background(AppTheme.cardBackground)
                .cornerRadius(10)

                Menu {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { opt in
                            Text(opt.rawValue).tag(opt)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down.circle")
                        .font(.system(size: 20))
                        .foregroundColor(AppTheme.accent)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            // Current folder breadcrumb
            if !currentPrefix.isEmpty {
                HStack {
                    Button(action: navigateUp) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                            Text("Back")
                        }
                        .font(.caption)
                        .foregroundColor(AppTheme.accent)
                    }

                    Text("/ " + currentPrefix)
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            // Main Content
            if isLoading {
                Spacer()
                ProgressView()
                    .tint(AppTheme.accent)
                Text("Reading archive...")
                    .font(.caption)
                    .foregroundColor(AppTheme.textSecondary)
                    .padding(.top, 8)
                Spacer()
            } else if let err = errorMessage {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 36))
                        .foregroundColor(AppTheme.error)
                    Text(err)
                        .font(.subheadline)
                        .foregroundColor(AppTheme.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Retry") {
                        loadArchive()
                    }
                    .foregroundColor(AppTheme.background)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(AppTheme.accent)
                    .cornerRadius(8)
                }
                Spacer()
            } else {
                List {
                    ForEach(filteredAndSortedItems) { item in
                        HStack(spacing: 12) {
                            if isSelectMode {
                                Image(systemName: selectedItemPaths.contains(item.path) ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(selectedItemPaths.contains(item.path) ? AppTheme.accent : AppTheme.textSecondary)
                                    .font(.system(size: 18))
                            }

                            Image(systemName: item.isDir ? "folder.fill" : "doc.fill")
                                .foregroundColor(item.isDir ? AppTheme.accent : AppTheme.textSecondary)
                                .font(.system(size: 20))

                            VStack(alignment: .leading, spacing: 2) {
                                HStack {
                                    Text(item.name)
                                        .font(.body)
                                        .foregroundColor(AppTheme.textPrimary)
                                        .lineLimit(1)
                                    if item.isEncrypted {
                                        Image(systemName: "lock.fill")
                                            .font(.caption2)
                                            .foregroundColor(AppTheme.warning)
                                    }
                                }

                                HStack(spacing: 8) {
                                    if !item.isDir {
                                        Text(item.formattedSize())
                                        Text("•")
                                        Text(item.formattedPackedSize())
                                    }
                                    if item.modifiedDate != nil {
                                        Text("•")
                                        Text(item.formattedDate())
                                    }
                                }
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                            }

                            Spacer()

                            if item.isDir && !isSelectMode {
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.divider)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isSelectMode {
                                toggleSelect(item)
                            } else if item.isDir {
                                navigateInto(item)
                            } else {
                                previewFile(item)
                            }
                        }
                        .listRowBackground(AppTheme.cardBackground)
                    }
                }
                .listStyle(PlainListStyle())
                .scrollContentBackground(.hidden)
            }

            // Bottom Action Bar
            HStack {
                if isSelectMode {
                    Text("\(selectedItemPaths.count) selected")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                    Spacer()
                    Button("Extract Selected") {
                        showExtractSheet = true
                    }
                    .disabled(selectedItemPaths.isEmpty)
                    .foregroundColor(selectedItemPaths.isEmpty ? AppTheme.textSecondary : AppTheme.accent)
                } else {
                    Button(action: { testArchive() }) {
                        Label(NSLocalizedString("btn_test", comment: ""), systemImage: "checkmark.shield")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textPrimary)
                    }
                    Spacer()
                    Button(action: { showExtractSheet = true }) {
                        Label(NSLocalizedString("btn_extract", comment: ""), systemImage: "tray.and.arrow.down.fill")
                            .font(.headline)
                            .foregroundColor(AppTheme.background)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(AppTheme.accent)
                            .cornerRadius(12)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(AppTheme.cardBackgroundSecondary)
        }
        .appBackground()
        .navigationTitle(archiveURL.lastPathComponent)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 12) {
                    Button(action: { isSelectMode.toggle(); selectedItemPaths.removeAll() }) {
                        Text(isSelectMode ? "Done" : "Select")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.accent)
                    }

                    Menu {
                        Button(action: { showInfoSheet = true }) {
                            Label(NSLocalizedString("btn_info", comment: ""), systemImage: "info.circle")
                        }
                        Button(action: { testArchive() }) {
                            Label(NSLocalizedString("btn_test", comment: ""), systemImage: "checkmark.shield")
                        }
                        Button(action: { shareURL = archiveURL; showShareSheet = true }) {
                            Label(NSLocalizedString("btn_share", comment: ""), systemImage: "square.and.arrow.up")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .foregroundColor(AppTheme.accent)
                    }
                }
            }
        }
        .sheet(isPresented: $showInfoSheet) {
            ArchiveInfoSheet(info: archiveInfo, archiveName: archiveURL.lastPathComponent)
        }
        .sheet(isPresented: $showExtractSheet) {
            ExtractDialogView(
                archiveURL: archiveURL,
                selectedItems: isSelectMode ? items.filter { selectedItemPaths.contains($0.path) } : []
            )
        }
        .sheet(isPresented: $showShareSheet) {
            if let u = shareURL {
                ActivityViewController(activityItems: [u])
            }
        }
        .sheet(item: $quickLookURL) { url in
            QuickLookPreview(url: url) {
                // Auto cleanup temp preview file
                try? FileManager.default.removeItem(at: url)
            }
        }
        .onAppear {
            loadArchive()
        }
    }

    private var currentLevelItems: [ArchiveItem] {
        if currentPrefix.isEmpty {
            // Root items
            var result: [ArchiveItem] = []
            var dirNames: Set<String> = []

            for item in items {
                let parts = item.path.split(separator: "/")
                if parts.count == 1 {
                    result.append(item)
                } else if parts.count > 1 {
                    let topDir = String(parts[0])
                    if !dirNames.contains(topDir) {
                        dirNames.insert(topDir)
                        result.append(ArchiveItem(name: topDir, path: topDir + "/", isDir: true))
                    }
                }
            }
            return result
        } else {
            // Subfolder items
            var result: [ArchiveItem] = []
            var subDirNames: Set<String> = []
            let prefix = currentPrefix.hasSuffix("/") ? currentPrefix : currentPrefix + "/"

            for item in items {
                if item.path.starts(with: prefix) && item.path != prefix {
                    let subPath = String(item.path.dropFirst(prefix.count))
                    let parts = subPath.split(separator: "/")
                    if parts.count == 1 {
                        var single = item
                        single.name = String(parts[0])
                        result.append(single)
                    } else if parts.count > 1 {
                        let subDir = String(parts[0])
                        if !subDirNames.contains(subDir) {
                            subDirNames.insert(subDir)
                            result.append(ArchiveItem(name: subDir, path: prefix + subDir + "/", isDir: true))
                        }
                    }
                }
            }
            return result
        }
    }

    private var filteredAndSortedItems: [ArchiveItem] {
        var list = currentLevelItems
        if !searchText.isEmpty {
            list = items.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        }

        switch sortOption {
        case .name:
            list.sort { $0.isDir == $1.isDir ? $0.name.lowercased() < $1.name.lowercased() : $0.isDir }
        case .size:
            list.sort { $0.size > $1.size }
        case .packedSize:
            list.sort { $0.packedSize > $1.packedSize }
        case .date:
            list.sort { ($0.modifiedDate ?? Date.distantPast) > ($1.modifiedDate ?? Date.distantPast) }
        }
        return list
    }

    private func toggleSelect(_ item: ArchiveItem) {
        if selectedItemPaths.contains(item.path) {
            selectedItemPaths.remove(item.path)
        } else {
            selectedItemPaths.insert(item.path)
        }
    }

    private func navigateInto(_ item: ArchiveItem) {
        currentPrefix = item.path
    }

    private func navigateUp() {
        var parts = currentPrefix.split(separator: "/").map(String.init)
        if !parts.isEmpty {
            parts.removeLast()
            currentPrefix = parts.isEmpty ? "" : parts.joined(separator: "/") + "/"
        } else {
            currentPrefix = ""
        }
    }

    private func loadArchive() {
        isLoading = true
        errorMessage = nil

        SevenZipBridge.shared.listArchive(at: archiveURL, password: enteredPassword.isEmpty ? nil : enteredPassword) { result in
            DispatchQueue.main.async {
                self.isLoading = false
                switch result {
                case .success(let (parsedItems, parsedInfo)):
                    self.items = parsedItems
                    self.archiveInfo = parsedInfo
                    AppSettings.shared.addRecentArchive(self.archiveURL)
                case .failure(let err):
                    self.errorMessage = err.localizedDescription
                }
            }
        }
    }

    private func testArchive() {
        let task = OperationTask(
            type: .test,
            title: "Test: \(archiveURL.lastPathComponent)",
            commandLine: ["7zz", "t", archiveURL.path, "-y"]
        )
        TaskManager.shared.enqueue(task: task)
    }

    private func previewFile(_ item: ArchiveItem) {
        guard !item.isDir else { return }

        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try? FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        let targetFile = tempDir.appendingPathComponent(item.name)

        isExtractingPreview = true
        SevenZipBridge.shared.execute(
            arguments: ["7zz", "e", archiveURL.path, item.path, "-o\(tempDir.path)", "-y"],
            completion: { code in
                DispatchQueue.main.async {
                    self.isExtractingPreview = false
                    if code == SZ_OK && FileManager.default.fileExists(atPath: targetFile.path) {
                        self.quickLookURL = targetFile
                    }
                }
            }
        )
    }
}
