//
//  BookmarkManager.swift
//  7Zip Security-Scoped Resource & Bookmark Management
//

import Foundation
#if canImport(Darwin)
import Darwin
#endif

public final class BookmarkManager {
    public static let shared = BookmarkManager()

    private init() {}

    public struct AccessReceipt {
        public let url: URL
        public let cleanup: () -> Void

        public init(url: URL, cleanup: @escaping () -> Void = {}) {
            self.url = url
            self.cleanup = cleanup
        }
    }

    /// Test whether raw POSIX open can read a file at the given path
    public static func canReadPOSIX(at path: String) -> Bool {
        #if canImport(Darwin)
        let fd = open(path, O_RDONLY)
        if fd >= 0 {
            close(fd)
            return true
        }
        return false
        #else
        return FileManager.default.isReadableFile(atPath: path)
        #endif
    }

    /// Prepare a file URL so that POSIX C/C++ (7-Zip core) can read it without errno=1 (Operation not permitted).
    /// 1. Tries activating security-scoped access if applicable.
    /// 2. If direct POSIX open works, returns sourceURL.
    /// 3. If POSIX open still fails (common in LiveContainer / SideStore across AppGroups / FileProvider),
    ///    safely imports a copy into the app's local sandbox Inbox directory where POSIX open is unconditionally allowed.
    public func prepareReadableURL(for sourceURL: URL) -> AccessReceipt {
        let isSecurityScoped = sourceURL.startAccessingSecurityScopedResource()

        // 1. Probe direct POSIX access on sourceURL
        if BookmarkManager.canReadPOSIX(at: sourceURL.path) {
            return AccessReceipt(url: sourceURL) {
                if isSecurityScoped {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }
        }

        // 2. Direct POSIX open failed (e.g. LiveContainer AppGroup boundary, FileProvider, or sandbox restriction).
        // Safely import a local copy into the application's Inbox directory using NSFileCoordinator / Foundation.
        let inboxDir = FileManager.default.temporaryDirectory.appendingPathComponent("Inbox", isDirectory: true)
        try? FileManager.default.createDirectory(at: inboxDir, withIntermediateDirectories: true)

        let targetURL = inboxDir.appendingPathComponent(sourceURL.lastPathComponent)
        try? FileManager.default.removeItem(at: targetURL)

        var copySuccess = false
        let coordinator = NSFileCoordinator()
        var coordError: NSError?

        coordinator.coordinate(readingItemAt: sourceURL, options: .withoutChanges, error: &coordError) { coordinatedURL in
            do {
                try FileManager.default.copyItem(at: coordinatedURL, to: targetURL)
                copySuccess = true
            } catch {
                if let data = try? Data(contentsOf: coordinatedURL) {
                    do {
                        try data.write(to: targetURL, options: .atomic)
                        copySuccess = true
                    } catch {}
                }
            }
        }

        if copySuccess && BookmarkManager.canReadPOSIX(at: targetURL.path) {
            return AccessReceipt(url: targetURL) {
                if isSecurityScoped {
                    sourceURL.stopAccessingSecurityScopedResource()
                }
            }
        }

        // Fallback: return sourceURL with security-scoped access active
        return AccessReceipt(url: sourceURL) {
            if isSecurityScoped {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }
    }

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
