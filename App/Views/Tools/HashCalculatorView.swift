//
//  HashCalculatorView.swift
//  7Zip File Hashes & Checksums Calculator
//

import SwiftUI
import UniformTypeIdentifiers

public struct HashCalculatorView: View {
    @State private var selectedFileURL: URL? = nil
    @State private var showFilePicker: Bool = false
    @State private var isCalculating: Bool = false
    @State private var hashes: [(name: String, value: String)] = []
    @State private var copiedIndex: Int? = nil

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // File selector card
                VStack(spacing: 12) {
                    if let url = selectedFileURL {
                        HStack {
                            Image(systemName: "doc.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(url.lastPathComponent)
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(1)
                                Text(url.path)
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.textSecondary)
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }
                            Spacer()
                            Button("Change") { showFilePicker = true }
                                .font(.subheadline)
                                .foregroundColor(AppTheme.accent)
                        }
                    } else {
                        Button(action: { showFilePicker = true }) {
                            VStack(spacing: 8) {
                                Image(systemName: "plus.circle.dashed")
                                    .font(.system(size: 36))
                                    .foregroundColor(AppTheme.accent)
                                Text(NSLocalizedString("select_file_hash", comment: ""))
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                        }
                    }
                }
                .appCardStyle()

                // Calculate button
                if selectedFileURL != nil {
                    Button(action: calculateHashes) {
                        HStack {
                            if isCalculating {
                                ProgressView()
                                    .tint(AppTheme.background)
                            } else {
                                Image(systemName: "number.square.fill")
                            }
                            Text(isCalculating ? "Calculating Hashes..." : NSLocalizedString("calculate_hash", comment: ""))
                                .font(.headline)
                                .bold()
                        }
                        .foregroundColor(AppTheme.background)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(isCalculating ? AppTheme.textSecondary : AppTheme.accent)
                        .cornerRadius(12)
                    }
                    .disabled(isCalculating)
                }

                // Hashes results card
                if !hashes.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Checksums & Hashes")
                            .font(.headline)
                            .foregroundColor(AppTheme.textPrimary)

                        ForEach(Array(hashes.enumerated()), id: \.offset) { idx, item in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(item.name)
                                        .font(.caption)
                                        .bold()
                                        .foregroundColor(AppTheme.textSecondary)
                                    Spacer()
                                    Button(action: { copyHash(item.value, at: idx) }) {
                                        HStack(spacing: 4) {
                                            Image(systemName: copiedIndex == idx ? "checkmark" : "doc.on.doc")
                                            Text(copiedIndex == idx ? "Copied" : "Copy")
                                        }
                                        .font(.caption2)
                                        .foregroundColor(AppTheme.accent)
                                    }
                                }
                                Text(item.value)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundColor(AppTheme.textPrimary)
                                    .lineLimit(2)
                            }
                            if idx < hashes.count - 1 {
                                Divider().background(AppTheme.divider)
                            }
                        }
                    }
                    .appCardStyle()
                }
            }
            .padding(16)
        }
        .appBackground()
        .navigationTitle(NSLocalizedString("hash_calc_title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFilePicker) {
            DocumentPicker(mode: .openFile(types: [.item]) { url in
                selectedFileURL = url
                hashes.removeAll()
            })
        }
    }

    private func calculateHashes() {
        guard let url = selectedFileURL else { return }
        isCalculating = true
        hashes.removeAll()

        // 7zz h -scrc* supports CRC32, CRC64, SHA1, SHA256, etc.
        let args = ["7zz", "h", "-scrcCRC32", "-scrcCRC64", "-scrcSHA1", "-scrcSHA256", url.path]

        var lines: [String] = []
        SevenZipBridge.shared.execute(
            arguments: args,
            onLog: { line in
                lines.append(line)
            },
            completion: { code in
                DispatchQueue.main.async {
                    self.isCalculating = false
                    self.parseHashOutput(lines)
                    AppTheme.triggerHaptic(type: code == SZ_OK ? .success : .error)
                }
            }
        )
    }

    private func parseHashOutput(_ lines: [String]) {
        var results: [(String, String)] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.contains("for data:") || trimmed.contains("for data and names:") {
                let parts = trimmed.split(separator: ":").map(String.init)
                if parts.count >= 2 {
                    let name = parts[0].trimmingCharacters(in: .whitespaces)
                    let val = parts[1].trimmingCharacters(in: .whitespaces)
                    results.append((name, val))
                }
            }
        }

        // If specific format lines not found, grab lines containing hashes
        if results.isEmpty {
            for line in lines {
                if line.contains("CRC32") || line.contains("SHA256") || line.contains("SHA1") {
                    results.append(("Checksum", line))
                }
            }
        }
        self.hashes = results
    }

    private func copyHash(_ value: String, at index: Int) {
        UIPasteboard.general.string = value
        AppTheme.triggerImpact(style: .light)
        copiedIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            if self.copiedIndex == index {
                self.copiedIndex = nil
            }
        }
    }
}
