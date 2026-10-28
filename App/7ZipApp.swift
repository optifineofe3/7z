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
                    BookmarkManager.shared.saveBookmark(for: incomingURL, key: "opened_external_url")
                    AppSettings.shared.addRecentArchive(incomingURL)
                    openedArchiveURL = incomingURL
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
