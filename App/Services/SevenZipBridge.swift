//
//  SevenZipBridge.swift
//  Swift Bridge to native 7-Zip C Core Wrapper
//

import Foundation

public final class SevenZipBridge {
    public static let shared = SevenZipBridge()

    private init() {
        sz_init_locale()
    }

    public typealias ProgressHandler = (sz_progress_info) -> Void
    public typealias LogHandler = (String) -> Void
    public typealias ErrorHandler = (String, Bool) -> Void
    public typealias PasswordHandler = (Int) -> String?
    public typealias OverwriteConfirmHandler = (String, String) -> Int
    public typealias CompletionHandler = (Int) -> Void

    // Thread-safe wrapper execution context
    private class ExecutionContext {
        var onProgress: ProgressHandler?
        var onLog: LogHandler?
        var onError: ErrorHandler?
        var getPassword: PasswordHandler?
        var confirmOverwrite: OverwriteConfirmHandler?
        var onComplete: CompletionHandler?
        var cachedPasswordCString: UnsafeMutablePointer<CChar>?

        deinit {
            if let p = cachedPasswordCString {
                let len = strlen(p)
                memset(p, 0, len)
                free(p)
            }
        }
    }

    /// Run 7-Zip command line on a background thread with >= 8MB stack
    public func execute(
        arguments: [String],
        onProgress: ProgressHandler? = nil,
        onLog: LogHandler? = nil,
        onError: ErrorHandler? = nil,
        getPassword: PasswordHandler? = nil,
        confirmOverwrite: OverwriteConfirmHandler? = nil,
        completion: @escaping (Int) -> Void
    ) {
        let ctx = ExecutionContext()
        ctx.onProgress = onProgress
        ctx.onLog = onLog
        ctx.onError = onError
        ctx.getPassword = getPassword
        ctx.confirmOverwrite = confirmOverwrite
        ctx.onComplete = completion

        // Use dedicated Thread with explicit 8MB stack size as required by Section 2.3
        let thread = Thread {
            let unmanagedCtx = Unmanaged.passRetained(ctx)
            let ptr = unmanagedCtx.toOpaque()

            var callbacks = sz_callbacks()
            callbacks.user_data = ptr

            callbacks.on_progress = { (infoPtr, userData) in
                guard let userData = userData, let info = infoPtr?.pointee else { return }
                let context = Unmanaged<ExecutionContext>.fromOpaque(userData).takeUnretainedValue()
                context.onProgress?(info)
            }

            callbacks.on_log = { (linePtr, userData) in
                guard let userData = userData, let linePtr = linePtr else { return }
                let line = String(cString: linePtr)
                let context = Unmanaged<ExecutionContext>.fromOpaque(userData).takeUnretainedValue()
                context.onLog?(line)
            }

            callbacks.on_error = { (msgPtr, isWarn, userData) in
                guard let userData = userData, let msgPtr = msgPtr else { return }
                let msg = String(cString: msgPtr)
                let context = Unmanaged<ExecutionContext>.fromOpaque(userData).takeUnretainedValue()
                context.onError?(msg, isWarn != 0)
            }

            callbacks.get_password = { (verify, userData) -> UnsafePointer<CChar>? in
                guard let userData = userData else { return nil }
                let context = Unmanaged<ExecutionContext>.fromOpaque(userData).takeUnretainedValue()
                if let pwd = context.getPassword?(Int(verify)) {
                    if let old = context.cachedPasswordCString {
                        let len = strlen(old)
                        memset(old, 0, len)
                        free(old)
                    }
                    let allocated = strdup(pwd)
                    context.cachedPasswordCString = allocated
                    return UnsafePointer(allocated)
                }
                return nil
            }

            callbacks.confirm_overwrite = { (existPtr, newPtr, userData) -> Int32 in
                guard let userData = userData else { return Int32(SZ_OVERWRITE_YES_ALL) }
                let exist = existPtr != nil ? String(cString: existPtr!) : ""
                let newFile = newPtr != nil ? String(cString: newPtr!) : ""
                let context = Unmanaged<ExecutionContext>.fromOpaque(userData).takeUnretainedValue()
                let choice = context.confirmOverwrite?(exist, newFile) ?? Int(SZ_OVERWRITE_YES_ALL)
                return Int32(choice)
            }

            callbacks.on_complete = { (code, userData) in
                guard let userData = userData else { return }
                let context = Unmanaged<ExecutionContext>.fromOpaque(userData).takeUnretainedValue()
                DispatchQueue.main.async {
                    context.onComplete?(Int(code))
                }
            }

            // Convert arguments to C string array
            var cArgs: [UnsafePointer<CChar>?] = arguments.map { arg in
                arg.withCString { s in
                    guard let p = strdup(s) else { return nil }
                    return UnsafePointer(p)
                }
            }

            let code = cArgs.withUnsafeBufferPointer { buf in
                sz_run(Int32(arguments.count), buf.baseAddress, &callbacks)
            }

            // Free argument C strings securely
            for ptr in cArgs {
                if let p = ptr {
                    let mut = UnsafeMutablePointer(mutating: p)
                    if strncmp(p, "-p", 2) == 0 {
                        let len = strlen(p)
                        memset(mut, 0, len)
                    }
                    free(mut)
                }
            }

            // Balance retained context
            unmanagedCtx.release()
            _ = code
        }

        // Set 8MB stack size
        thread.stackSize = 8 * 1024 * 1024
        thread.name = "7-Zip Core Worker"
        thread.start()
    }

    /// Cancel active operation
    public func cancel() {
        sz_cancel()
    }

    /// Safe available memory budget switch (e.g. "-mmemuse=600m")
    public func safeMemoryLimitSwitch(margin: Double = 0.70) -> String {
        var buf = [CChar](repeating: 0, count: 64)
        sz_get_safe_memuse_switch(&buf, buf.count, margin)
        return String(cString: buf)
    }

    /// Get English error description for exit code
    public func errorMessage(for exitCode: Int) -> String {
        guard let cStr = sz_get_error_message(Int32(exitCode), 0) else {
            return "Unknown error"
        }
        return String(cString: cStr)
    }

    private static let sltDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.timeZone = TimeZone(secondsFromGMT: 0)
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()

    /// Parse archive contents using "l -slt"
    public func listArchive(
        at archiveURL: URL,
        password: String? = nil,
        completion: @escaping (Result<([ArchiveItem], ArchiveInfo), Error>) -> Void
    ) {
        let receipt = BookmarkManager.shared.prepareReadableURL(for: archiveURL)

        var args = ["7zz", "l", "-slt", "-y"]
        if let pwd = password, !pwd.isEmpty {
            args.append("-p\(pwd)")
        }
        args.append(receipt.url.path)

        var logLines: [String] = []
        var errorLines: [String] = []

        execute(
            arguments: args,
            onLog: { line in
                logLines.append(line)
            },
            onError: { msg, isWarn in
                if !isWarn { errorLines.append(msg) }
            },
            getPassword: { _ in password },
            confirmOverwrite: { _, _ in Int(SZ_OVERWRITE_YES_ALL) },
            completion: { code in
                receipt.cleanup()
                if code != SZ_OK && code != SZ_WARNING {
                    let errDesc = self.errorMessage(for: code)
                    let detailed = errorLines.isEmpty ? errDesc : errorLines.joined(separator: "\n")
                    completion(.failure(NSError(domain: "7Zip", code: code, userInfo: [NSLocalizedDescriptionKey: detailed])))
                    return
                }

                var (items, info) = self.parseSltOutput(logLines)
                if info.physicalSize == 0 {
                    if let attr = try? FileManager.default.attributesOfItem(atPath: receipt.url.path),
                       let sz = attr[.size] as? UInt64 {
                        info.physicalSize = sz
                    } else if let attr = try? FileManager.default.attributesOfItem(atPath: archiveURL.path),
                              let sz = attr[.size] as? UInt64 {
                        info.physicalSize = sz
                    }
                }
                completion(.success((items, info)))
            }
        )
    }

    private func parseSltOutput(_ lines: [String]) -> ([ArchiveItem], ArchiveInfo) {
        var items: [ArchiveItem] = []
        var info = ArchiveInfo()

        var currentProperties: [String: String] = [:]
        var isHeaderSection = true

        let commitBlock = {
            if !currentProperties.isEmpty {
                if isHeaderSection {
                    if let type = currentProperties["Type"] {
                        info.format = type
                    }
                    if let phys = currentProperties["Physical Size"], let s = UInt64(phys) {
                        info.physicalSize = s
                    }
                    if let hdr = currentProperties["Headers Size"], let h = UInt64(hdr) {
                        info.headersSize = h
                    }
                    if let sol = currentProperties["Solid"] {
                        info.isSolid = (sol == "+" || sol.lowercased() == "true")
                    }
                    if let m = currentProperties["Method"] {
                        info.method = m
                    }
                    if let blk = currentProperties["Blocks"], let b = Int(blk) {
                        info.blocksCount = b
                    }
                    for (k, v) in currentProperties {
                        info.rawProperties[k] = v
                    }
                    // Keep isHeaderSection = true until "----------" is hit
                } else if let path = currentProperties["Path"], !path.isEmpty {
                    // Strict directory determination by Folder property from 7-Zip -slt
                    let isDir = (currentProperties["Folder"] == "+")
                    let size = UInt64(currentProperties["Size"] ?? "0") ?? 0
                    let packed = UInt64(currentProperties["Packed Size"] ?? "0") ?? 0
                    let crc = currentProperties["CRC"] ?? ""
                    let method = currentProperties["Method"] ?? ""
                    let attr = currentProperties["Attributes"] ?? ""
                    let encrypted = (currentProperties["Encrypted"] == "+")

                    var modDate: Date? = nil
                    if let modStr = currentProperties["Modified"] {
                        let cleanMod = modStr.count > 19 ? String(modStr.prefix(19)) : modStr
                        modDate = Self.sltDateFormatter.date(from: cleanMod)
                    }

                    let normalizedPath = path.replacingOccurrences(of: "\\", with: "/")
                    let filename = (normalizedPath as NSString).lastPathComponent
                    let item = ArchiveItem(
                        name: filename.isEmpty ? normalizedPath : filename,
                        path: normalizedPath,
                        size: size,
                        packedSize: packed,
                        modifiedDate: modDate,
                        crc: crc,
                        method: method,
                        attributes: attr,
                        isDir: isDir,
                        isEncrypted: encrypted
                    )
                    items.append(item)
                    if isDir {
                        info.foldersCount += 1
                    } else {
                        info.filesCount += 1
                    }
                }
                currentProperties.removeAll()
            }
        }

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.starts(with: "----------") {
                commitBlock()
                isHeaderSection = false
                continue
            }
            if trimmed.isEmpty {
                commitBlock()
                continue
            }

            if let eqIndex = trimmed.firstIndex(of: "=") {
                let key = String(trimmed[..<eqIndex]).trimmingCharacters(in: .whitespaces)
                let val = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
                currentProperties[key] = val
            }
        }
        commitBlock()

        return (items, info)
    }
}
