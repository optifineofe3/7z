//
//  BookmarkManager.swift
//  7Zip Security-Scoped Resource & Bookmark Management
//

import Foundation

public final class BookmarkManager {
    public static let shared = BookmarkManager()

    private init() {}

    /// Safely access a security-scoped URL during the execution of a block
    public func withSecurityScopedURL<T>(url: URL, block: (URL) throws -> T) rethrows -> T {
        let isAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if isAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }
        return try block(url)
    }

    /// Store a security-scoped bookmark for persistent folder/file access
    public func saveBookmark(for url: URL, key: String) {
        do {
            let data = try url.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Failed to save security-scoped bookmark: \(error)")
        }
    }

    /// Resolve stored bookmark
    public func resolveBookmark(key: String) -> URL? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        var isStale = false
        do {
            let resolved = try URL(
                resolvingBookmarkData: data,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                saveBookmark(for: resolved, key: key)
            }
            return resolved
        } catch {
            print("Failed to resolve bookmark for key \(key): \(error)")
            return nil
        }
    }
}
