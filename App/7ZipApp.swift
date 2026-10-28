//
//  7ZipApp.swift
//  7Zip iOS Application Main Entrypoint
//

import SwiftUI
import UIKit

@main
struct SevenZipApp: App {
    @State private var openedArchiveURL: URL? = nil

    init() {
        // Enforce dark mode globally across all UIKit views and view controllers
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            windowScene.windows.forEach { window in
                window.overrideUserInterfaceStyle = .dark
            }
        }
        UIView.appearance().overrideUserInterfaceStyle = .dark
        UINavigationBar.appearance().overrideUserInterfaceStyle = .dark
        UITabBar.appearance().overrideUserInterfaceStyle = .dark
    }

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .preferredColorScheme(.dark)
                .onOpenURL { incomingURL in
                    // Handle "Open in..." from Files, Safari, Telegram, Mail, etc.
                    let receipt = BookmarkManager.shared.prepareReadableURL(for: incomingURL)
                    BookmarkManager.shared.saveBookmark(for: receipt.url, key: "opened_external_url")
                    AppSettings.shared.addRecentArchive(receipt.url)
                    openedArchiveURL = receipt.url
                }
                .sheet(item: $openedArchiveURL) { url in
                    NavigationView {
                        ArchiveBrowserView(archiveURL: url)
                    }
                    .preferredColorScheme(.dark)
                }
        }
    }
}

// Extension to allow URL to be used with sheet(item: ...)
extension URL: Identifiable {
    public var id: String { self.absoluteString }
}
