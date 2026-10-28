//
//  ArchiveInfoSheet.swift
//  7Zip Archive Metadata Info Sheet
//

import SwiftUI

public struct ArchiveInfoSheet: View {
    public let info: ArchiveInfo
    public let archiveName: String
    @Environment(\.dismiss) private var dismiss

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "archivebox.fill")
                                .font(.system(size: 28))
                                .foregroundColor(AppTheme.accent)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(archiveName)
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(info.format.uppercased())
                                    .font(.caption)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            Spacer()
                        }
                    }
                    .appCardStyle()

                    // Main stats
                    VStack(spacing: 12) {
                        InfoRow(title: "Format", value: info.format)
                        Divider().background(AppTheme.divider)
                        InfoRow(title: "Physical Size", value: info.formattedPhysicalSize())
                        Divider().background(AppTheme.divider)
                        InfoRow(title: "Headers Size", value: info.formattedHeadersSize())
                        Divider().background(AppTheme.divider)
                        InfoRow(title: "Solid Archive", value: info.isSolid ? "Yes" : "No")
                        Divider().background(AppTheme.divider)
                        InfoRow(title: "Compression Method", value: info.method.isEmpty ? "--" : info.method)
                        Divider().background(AppTheme.divider)
                        InfoRow(title: "Total Files", value: "\(info.filesCount)")
                        Divider().background(AppTheme.divider)
                        InfoRow(title: "Total Folders", value: "\(info.foldersCount)")
                    }
                    .appCardStyle()

                    // Extended properties if any
                    if !info.rawProperties.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("All Properties")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.textSecondary)

                            ForEach(info.rawProperties.keys.sorted(), id: \.self) { key in
                                if let val = info.rawProperties[key], !val.isEmpty {
                                    InfoRow(title: key, value: val)
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
            .navigationTitle(NSLocalizedString("archive_info", comment: ""))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(AppTheme.textSecondary)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
    }
}

private struct InfoRow: View {
    let title: String
    let value: String

    var body: some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(AppTheme.textSecondary)
            Spacer()
            Text(value)
                .font(.body)
                .foregroundColor(AppTheme.textPrimary)
        }
    }
}
