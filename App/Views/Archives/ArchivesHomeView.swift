//
//  ArchivesHomeView.swift
//  7Zip Main Archives View: Big Action Buttons & Recent Archives
//

import SwiftUI
import UniformTypeIdentifiers

public struct ArchivesHomeView: View {
    @ObservedObject private var settings = AppSettings.shared
    @State private var showFilePicker: Bool = false
    @State private var showCreateArchiveSheet: Bool = false
    @State private var selectedArchiveURL: URL? = nil
    @State private var navigateToBrowser: Bool = false

    public init() {}

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Big Action Buttons
                    HStack(spacing: 16) {
                        // Create Archive Button
                        Button(action: { showCreateArchiveSheet = true }) {
                            VStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 36))
                                    .foregroundColor(AppTheme.background)
                                Text(NSLocalizedString("create_archive_btn", comment: ""))
                                    .font(.headline)
                                    .foregroundColor(AppTheme.background)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(AppTheme.accent)
                            .cornerRadius(AppTheme.cornerRadius)
                        }

                        // Open Archive Button
                        Button(action: { showFilePicker = true }) {
                            VStack(spacing: 12) {
                                Image(systemName: "folder.badge.gearshape")
                                    .font(.system(size: 36))
                                    .foregroundColor(AppTheme.textPrimary)
                                Text(NSLocalizedString("open_archive_btn", comment: ""))
                                    .font(.headline)
                                    .foregroundColor(AppTheme.textPrimary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 24)
                            .background(AppTheme.cardBackgroundSecondary)
                            .cornerRadius(AppTheme.cornerRadius)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppTheme.cornerRadius)
                                    .stroke(AppTheme.divider, lineWidth: 1)
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)

                    // Recent Archives Section
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(NSLocalizedString("recent_archives", comment: ""))
                                .font(.title3)
                                .bold()
                                .foregroundColor(AppTheme.textPrimary)
                            Spacer()
                            if !settings.recentArchives.isEmpty {
                                Button(NSLocalizedString("clear_recent", comment: "")) {
                                    settings.clearRecents()
                                }
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                            }
                        }
                        .padding(.horizontal, 16)

                        if settings.recentArchives.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "archivebox")
                                    .font(.system(size: 40))
                                    .foregroundColor(AppTheme.textSecondary)
                                Text(NSLocalizedString("no_recent_archives", comment: ""))
                                    .font(.subheadline)
                                    .foregroundColor(AppTheme.textSecondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 48)
                            .appCardStyle()
                            .padding(.horizontal, 16)
                        } else {
                            VStack(spacing: 1) {
                                ForEach(settings.recentArchives, id: \.self) { url in
                                    NavigationLink(destination: ArchiveBrowserView(archiveURL: url)) {
                                        HStack(spacing: 14) {
                                            Image(systemName: "doc.zipper")
                                                .font(.system(size: 24))
                                                .foregroundColor(AppTheme.accent)

                                            VStack(alignment: .leading, spacing: 2) {
                                                Text(url.lastPathComponent)
                                                    .font(.body)
                                                    .foregroundColor(AppTheme.textPrimary)
                                                    .lineLimit(1)
                                                Text(url.deletingLastPathComponent().path)
                                                    .font(.caption2)
                                                    .foregroundColor(AppTheme.textSecondary)
                                                    .lineLimit(1)
                                                    .truncationMode(.middle)
                                            }
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.caption)
                                                .foregroundColor(AppTheme.divider)
                                        }
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 14)
                                        .background(AppTheme.cardBackground)
                                    }
                                    if url != settings.recentArchives.last {
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

                    // Hidden navigation link for picker selection
                    if let selected = selectedArchiveURL {
                        NavigationLink(
                            destination: ArchiveBrowserView(archiveURL: selected),
                            isActive: $navigateToBrowser
                        ) {
                            EmptyView()
                        }
                    }
                }
            }
            .appBackground()
            .navigationTitle("7-Zip")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showFilePicker) {
                DocumentPicker(mode: .openFile(types: [.archive, .data], asCopy: true) { pickedURL in
                    let receipt = BookmarkManager.shared.prepareReadableURL(for: pickedURL)
                    BookmarkManager.shared.saveBookmark(for: receipt.url, key: "last_picked_archive")
                    selectedArchiveURL = receipt.url
                    navigateToBrowser = true
                })
            }
            .sheet(isPresented: $showCreateArchiveSheet) {
                CreateArchiveView()
            }
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(.dark)
    }
}
