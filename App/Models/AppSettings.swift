//
//  AppSettings.swift
//  7Zip App Preferences & Settings State
//

import Foundation
import SwiftUI

public class AppSettings: ObservableObject {
    public static let shared = AppSettings()

    @AppStorage("default_overwrite_policy") public var defaultOverwritePolicy: Int = 0 // 0 = Ask, 1 = Overwrite, 2 = Skip, 3 = Auto-rename
    @AppStorage("default_preset_name") public var defaultPresetName: String = "Normal"
    @AppStorage("auto_clean_temp") public var autoCleanTemp: Bool = true
    @AppStorage("show_hidden_files") public var showHiddenFiles: Bool = false
    @AppStorage("size_binary_mode") public var sizeBinaryMode: Bool = true
    @AppStorage("enable_haptics") public var enableHaptics: Bool = true
    @AppStorage("developer_mode") public var developerMode: Bool = false

    @Published public var recentArchives: [URL] = []

    private let recentKey = "saved_recent_archives_urls"

    private init() {
        loadRecents()
    }

    public func addRecentArchive(_ url: URL) {
        var list = recentArchives.filter { $0.path != url.path }
        list.insert(url, at: 0)
        if list.count > 20 {
            list = Array(list.prefix(20))
        }
        recentArchives = list
        saveRecents()
    }

    public func removeRecentArchive(_ url: URL) {
        recentArchives.removeAll { $0.path == url.path }
        saveRecents()
    }

    public func clearRecents() {
        recentArchives.removeAll()
        UserDefaults.standard.removeObject(forKey: recentKey)
    }

    private func saveRecents() {
        let bookmarks = recentArchives.compactMap { (url: URL) -> Data? in
            try? url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
        }
        UserDefaults.standard.set(bookmarks, forKey: recentKey)
    }

    private func loadRecents() {
        guard let bookmarks = UserDefaults.standard.array(forKey: recentKey) as? [Data] else { return }
        var urls: [URL] = []
        for data in bookmarks {
            var isStale = false
            if let resolved = try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale), !isStale {
                urls.append(resolved)
            }
        }
        self.recentArchives = urls
    }

    public func clearTempCache() {
        let tempDir = FileManager.default.temporaryDirectory
        if let files = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil) {
            for f in files {
                try? FileManager.default.removeItem(at: f)
            }
        }
    }
}
