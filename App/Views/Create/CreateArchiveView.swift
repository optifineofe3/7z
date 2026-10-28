//
//  CreateArchiveView.swift
//  7Zip Desktop-Parity "Add to Archive" Form
//

import SwiftUI
import UniformTypeIdentifiers

public struct CreateArchiveView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var appSettings = AppSettings.shared

    @State private var settings = CompressionSettings()
    @State private var archiveName: String = "Archive"
    @State private var destinationFolderURL: URL
    @State private var inputURLs: [URL] = []

    // Custom volume size string
    @State private var volumeSelection: String = "none"
    @State private var customVolumeSize: String = ""

    // Password visibility
    @State private var showPassword: Bool = false

    // Pickers
    @State private var showFilePicker: Bool = false
    @State private var showFolderPicker: Bool = false
    @State private var showDestinationPicker: Bool = false

    // Preset selection
    @State private var selectedPreset: String = "Normal"

    public init(initialInputURLs: [URL] = []) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        _destinationFolderURL = State(initialValue: docs)
        _inputURLs = State(initialValue: initialInputURLs)
        if let first = initialInputURLs.first {
            _archiveName = State(initialValue: first.deletingPathExtension().lastPathComponent)
        }
    }

    public var body: some View {
        NavigationView {
            Form {
                // Section: Input files & Output Name
                Section(header: Text(NSLocalizedString("section_general", comment: "")).foregroundColor(AppTheme.textSecondary)) {
                    // Files count and add button
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(inputURLs.isEmpty ? "No files selected" : "\(inputURLs.count) item(s) selected")
                                .font(.headline)
                                .foregroundColor(AppTheme.textPrimary)
                            if let first = inputURLs.first {
                                Text(first.lastPathComponent + (inputURLs.count > 1 ? " and others" : ""))
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        Spacer()
                        Menu {
                            Button("Add Files...") { showFilePicker = true }
                            Button("Add Folder...") { showFolderPicker = true }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.system(size: 22))
                                .foregroundColor(AppTheme.accent)
                        }
                    }
                    .padding(.vertical, 4)

                    // Archive Name
                    HStack {
                        Text(NSLocalizedString("archive_name", comment: ""))
                            .foregroundColor(AppTheme.textSecondary)
                        Spacer()
                        TextField("Name", text: $archiveName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppTheme.textPrimary)
                        Text(settings.format.defaultExtension)
                            .foregroundColor(AppTheme.textSecondary)
                    }

                    // Destination Folder
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(NSLocalizedString("destination_folder", comment: ""))
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Text(destinationFolderURL.lastPathComponent)
                                .font(.body)
                                .foregroundColor(AppTheme.textPrimary)
                        }
                        Spacer()
                        Button(NSLocalizedString("choose_folder", comment: "")) {
                            showDestinationPicker = true
                        }
                        .font(.subheadline)
                        .foregroundColor(AppTheme.accent)
                    }

                    // Format Picker
                    Picker(NSLocalizedString("archive_format", comment: ""), selection: $settings.format) {
                        ForEach(ArchiveFormat.allCases) { fmt in
                            Text(fmt.displayName).tag(fmt)
                        }
                    }
                    .foregroundColor(AppTheme.textPrimary)
                    .onChange(of: settings.format) { newFormat in
                        if !newFormat.supportedMethods.contains(settings.method) {
                            settings.method = newFormat.supportedMethods.first ?? .copy
                        }
                    }

                    // Level Picker
                    Picker(NSLocalizedString("compression_level", comment: ""), selection: $settings.level) {
                        ForEach(CompressionLevel.allCases) { lvl in
                            Text(lvl.localizedName).tag(lvl)
                        }
                    }
                    .foregroundColor(AppTheme.textPrimary)

                    // Method Picker
                    Picker(NSLocalizedString("compression_method", comment: ""), selection: $settings.method) {
                        ForEach(settings.format.supportedMethods) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .foregroundColor(AppTheme.textPrimary)
                }
                .listRowBackground(AppTheme.cardBackground)

                // Section: Compression & Memory Budget
                Section(header: Text(NSLocalizedString("section_compression", comment: "")).foregroundColor(AppTheme.textSecondary)) {
                    // Dictionary Size
                    Picker(NSLocalizedString("dict_size", comment: ""), selection: $settings.dictionarySizeMB) {
                        Text("1 MB").tag(1)
                        Text("2 MB").tag(2)
                        Text("4 MB").tag(4)
                        Text("8 MB").tag(8)
                        Text("16 MB").tag(16)
                        Text("32 MB").tag(32)
                        Text("64 MB").tag(64)
                        Text("128 MB").tag(128)
                        Text("256 MB").tag(256)
                        Text("512 MB").tag(512)
                        Text("1024 MB (1 GB)").tag(1024)
                        Text("1536 MB (1.5 GB)").tag(1536)
                    }
                    .foregroundColor(AppTheme.textPrimary)

                    // Word Size
                    Picker(NSLocalizedString("word_size", comment: ""), selection: $settings.wordSize) {
                        Text("32").tag(32)
                        Text("64").tag(64)
                        Text("128").tag(128)
                        Text("273").tag(273)
                    }
                    .foregroundColor(AppTheme.textPrimary)

                    // Solid Block Size
                    Picker(NSLocalizedString("solid_size", comment: ""), selection: $settings.solidBlockSizeMB) {
                        Text("Non-solid").tag(0)
                        Text("64 MB").tag(64)
                        Text("256 MB").tag(256)
                        Text("1 GB").tag(1024)
                        Text("2 GB").tag(2048)
                        Text("4 GB").tag(4096)
                        Text("Solid").tag(-1)
                    }
                    .foregroundColor(AppTheme.textPrimary)

                    // Thread count
                    Stepper(
                        value: $settings.threads,
                        in: 1...ProcessInfo.processInfo.activeProcessorCount
                    ) {
                        HStack {
                            Text(NSLocalizedString("threads_count", comment: ""))
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text("\(settings.threads)")
                                .foregroundColor(AppTheme.textPrimary)
                        }
                    }

                    // Memory estimate and warning
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(String(format: NSLocalizedString("memory_comp_estimate", comment: ""), ByteCountFormatter.string(fromByteCount: Int64(settings.estimatedCompressionMemoryBytes()), countStyle: .binary)))
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            Spacer()
                            Text(String(format: NSLocalizedString("memory_decomp_estimate", comment: ""), ByteCountFormatter.string(fromByteCount: Int64(settings.estimatedDecompressionMemoryBytes()), countStyle: .binary)))
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }

                        let safety = MemoryBudget.checkSafety(settings: settings)
                        if !safety.isSafe {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(alignment: .top, spacing: 6) {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(AppTheme.warning)
                                    Text(String(format: NSLocalizedString("memory_warning", comment: ""), MemoryBudget.formattedAvailable()))
                                        .font(.caption2)
                                        .foregroundColor(AppTheme.warning)
                                }
                                Button(action: {
                                    MemoryBudget.autoReduce(settings: &settings)
                                }) {
                                    Text(NSLocalizedString("btn_auto_reduce", comment: ""))
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(AppTheme.accent)
                                }
                                .padding(.vertical, 4)
                            }
                            .padding(8)
                            .background(AppTheme.cardBackgroundSecondary)
                            .cornerRadius(8)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowBackground(AppTheme.cardBackground)

                // Section: Split to Volumes
                Section(header: Text(NSLocalizedString("section_volumes", comment: "")).foregroundColor(AppTheme.textSecondary)) {
                    Picker(NSLocalizedString("volume_size", comment: ""), selection: $volumeSelection) {
                        Text(NSLocalizedString("vol_none", comment: "")).tag("none")
                        Text("10M (10 MB)").tag("10M")
                        Text("100M (100 MB)").tag("100M")
                        Text("650M (CD 650)").tag("650M")
                        Text("700M (CD 700)").tag("700M")
                        Text("1000M (1 GB)").tag("1000M")
                        Text("4092M (FAT32)").tag("4092M")
                        Text("4480M (DVD)").tag("4480M")
                        Text(NSLocalizedString("vol_custom", comment: "")).tag("custom")
                    }
                    .foregroundColor(AppTheme.textPrimary)
                    .onChange(of: volumeSelection) { val in
                        if val != "custom" {
                            settings.splitVolumeSize = (val == "none") ? "" : val
                        }
                    }

                    if volumeSelection == "custom" {
                        TextField("e.g. 50M or 2G", text: $customVolumeSize)
                            .foregroundColor(AppTheme.textPrimary)
                            .onChange(of: customVolumeSize) { sz in
                                settings.splitVolumeSize = sz.trimmingCharacters(in: .whitespaces)
                            }
                    }
                }
                .listRowBackground(AppTheme.cardBackground)

                // Section: Modes & Options
                Section(header: Text(NSLocalizedString("section_update_paths", comment: "")).foregroundColor(AppTheme.textSecondary)) {
                    Picker(NSLocalizedString("update_mode", comment: ""), selection: $settings.updateMode) {
                        ForEach(UpdateMode.allCases) { m in
                            Text(m.localizedName).tag(m)
                        }
                    }
                    .foregroundColor(AppTheme.textPrimary)

                    Picker(NSLocalizedString("path_mode", comment: ""), selection: $settings.pathMode) {
                        ForEach(PathMode.allCases) { p in
                            Text(p.localizedName).tag(p)
                        }
                    }
                    .foregroundColor(AppTheme.textPrimary)

                    Toggle(NSLocalizedString("preserve_timestamps", comment: ""), isOn: $settings.preserveTimestamps)
                        .tint(AppTheme.accent)
                    Toggle(NSLocalizedString("preserve_symlinks", comment: ""), isOn: $settings.preserveSymlinks)
                        .tint(AppTheme.accent)
                    Toggle(NSLocalizedString("recursive", comment: ""), isOn: $settings.recursive)
                        .tint(AppTheme.accent)

                    HStack {
                        Text(NSLocalizedString("exclude_mask", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("*.tmp *.log", text: $settings.excludeMask)
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.trailing)
                    }

                    HStack {
                        Text(NSLocalizedString("include_mask", comment: ""))
                            .font(.subheadline)
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("*", text: $settings.includeMask)
                            .foregroundColor(AppTheme.textPrimary)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .listRowBackground(AppTheme.cardBackground)

                // Section: Encryption
                Section(header: Text(NSLocalizedString("section_encryption", comment: "")).foregroundColor(AppTheme.textSecondary)) {
                    if showPassword {
                        TextField(NSLocalizedString("password", comment: ""), text: $settings.password)
                            .foregroundColor(AppTheme.textPrimary)
                        TextField(NSLocalizedString("confirm_password", comment: ""), text: $settings.confirmPassword)
                            .foregroundColor(AppTheme.textPrimary)
                    } else {
                        SecureField(NSLocalizedString("password", comment: ""), text: $settings.password)
                            .foregroundColor(AppTheme.textPrimary)
                        SecureField(NSLocalizedString("confirm_password", comment: ""), text: $settings.confirmPassword)
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    Toggle(NSLocalizedString("show_password", comment: ""), isOn: $showPassword)
                        .tint(AppTheme.accent)

                    if settings.format == .sevenZip {
                        Toggle(NSLocalizedString("encrypt_headers", comment: ""), isOn: $settings.encryptFileNames)
                            .tint(AppTheme.accent)
                    }
                }
                .listRowBackground(AppTheme.cardBackground)

                // Section: Presets & Parameters
                Section(header: Text(NSLocalizedString("section_advanced", comment: "")).foregroundColor(AppTheme.textSecondary)) {
                    Picker(NSLocalizedString("presets_title", comment: ""), selection: $selectedPreset) {
                        Text(NSLocalizedString("preset_fast", comment: "")).tag("Fast")
                        Text(NSLocalizedString("preset_normal", comment: "")).tag("Normal")
                        Text(NSLocalizedString("preset_maximum", comment: "")).tag("Maximum")
                        Text(NSLocalizedString("preset_max_encrypted", comment: "")).tag("MaxEncrypted")
                    }
                    .foregroundColor(AppTheme.textPrimary)
                    .onChange(of: selectedPreset) { p in
                        switch p {
                        case "Fast": settings = .presetFast
                        case "Normal": settings = .presetNormal
                        case "Maximum": settings = .presetMaximum
                        case "MaxEncrypted": settings = .presetMaxEncrypted
                        default: break
                        }
                    }

                    HStack {
                        Text(NSLocalizedString("custom_parameters", comment: ""))
                            .foregroundColor(AppTheme.textSecondary)
                        TextField("-m0=lzma2", text: $settings.customParameters)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(AppTheme.textPrimary)
                    }

                    if appSettings.developerMode {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(NSLocalizedString("resulting_cli", comment: ""))
                                .font(.caption2)
                                .foregroundColor(AppTheme.textSecondary)
                            let cli = settings.buildArguments(
                                archivePath: destinationFolderURL.appendingPathComponent(archiveName + settings.format.defaultExtension).path,
                                inputPaths: inputURLs.map { $0.path }
                            ).joined(separator: " ")
                            Text(cli)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(AppTheme.textPrimary)
                                .padding(8)
                                .background(AppTheme.cardBackgroundSecondary)
                                .cornerRadius(8)
                        }
                        .padding(.vertical, 4)
                    }
                }
                .listRowBackground(AppTheme.cardBackground)
            }
            .hideScrollContentBackground()
            .appBackground()
            .navigationTitle(NSLocalizedString("create_archive_title", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(NSLocalizedString("btn_cancel", comment: "")) {
                        dismiss()
                    }
                    .foregroundColor(AppTheme.textSecondary)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: startCompression) {
                        Text(NSLocalizedString("btn_compress", comment: ""))
                            .bold()
                            .foregroundColor(AppTheme.background)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(inputURLs.isEmpty ? AppTheme.divider : AppTheme.accent)
                            .cornerRadius(12)
                    }
                    .disabled(inputURLs.isEmpty)
                }
            }
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(mode: .openFile(types: [.item]) { picked in
                    if !inputURLs.contains(picked) {
                        inputURLs.append(picked)
                    }
                })
            }
            .sheet(isPresented: $showFolderPicker) {
                DocumentPicker(mode: .openFolder { picked in
                    if !inputURLs.contains(picked) {
                        inputURLs.append(picked)
                    }
                })
            }
            .sheet(isPresented: $showDestinationPicker) {
                DocumentPicker(mode: .openFolder { picked in
                    destinationFolderURL = picked
                })
            }
        }
        .preferredColorScheme(.dark)
    }

    private func startCompression() {
        guard !inputURLs.isEmpty else { return }

        let fullArchivePath = destinationFolderURL
            .appendingPathComponent(archiveName + settings.format.defaultExtension)
            .path

        let inputPaths = inputURLs.map { $0.path }
        let args = settings.buildArguments(archivePath: fullArchivePath, inputPaths: inputPaths)

        let taskTitle = "Compress: \(archiveName)\(settings.format.defaultExtension)"
        let task = OperationTask(type: .compress, title: taskTitle, commandLine: args)
        task.securityScopedURLs.append(destinationFolderURL)
        task.securityScopedURLs.append(contentsOf: inputURLs)
        TaskManager.shared.enqueue(task: task)

        dismiss()
    }
}
