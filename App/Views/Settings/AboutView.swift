//
//  AboutView.swift
//  7Zip Legal Licenses & Information View
//

import SwiftUI

public struct AboutView: View {
    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header
                VStack(spacing: 8) {
                    Image(systemName: "archivebox.fill")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.accent)
                    Text("7-Zip for iOS")
                        .font(.title2)
                        .bold()
                        .foregroundColor(AppTheme.textPrimary)
                    Text("Version 24.08 (arm64)")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .appCardStyle()

                // License Section
                VStack(alignment: .leading, spacing: 10) {
                    Text(NSLocalizedString("license_info", comment: ""))
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Text("7-Zip is open source software. Most of the source code is under the GNU LGPL version 2.1 (or later). The unRAR code is distributed under a mixed license with RAR restrictions.")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineSpacing(4)

                    Divider().background(AppTheme.divider)

                    Text("unRAR License Notice:")
                        .font(.caption)
                        .bold()
                        .foregroundColor(AppTheme.textPrimary)

                    Text("The unRAR portion of 7-Zip cannot be used to re-create the RAR compression algorithm, which is proprietary. Distribution of unRAR source code and binaries is permitted with proper credit to the author, Eugene Roshal.")
                        .font(.caption2)
                        .foregroundColor(AppTheme.textSecondary)
                        .lineSpacing(3)
                }
                .appCardStyle()

                // Source Code & Credits
                VStack(alignment: .leading, spacing: 10) {
                    Text("Credits")
                        .font(.headline)
                        .foregroundColor(AppTheme.textPrimary)

                    Text("Original 7-Zip Core by Igor Pavlov (https://www.7-zip.org).")
                        .font(.caption)
                        .foregroundColor(AppTheme.textSecondary)

                    Divider().background(AppTheme.divider)

                    Link(destination: URL(string: "https://github.com/ipavlov/7zip")!) {
                        HStack {
                            Text("Official 7-Zip Repository")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.accent)
                            Spacer()
                            Image(systemName: "arrow.up.right")
                                .font(.caption)
                                .foregroundColor(AppTheme.textSecondary)
                        }
                    }
                }
                .appCardStyle()
            }
            .padding(16)
        }
        .appBackground()
        .navigationTitle(NSLocalizedString("about_title", comment: ""))
        .navigationBarTitleDisplayMode(.inline)
    }
}
