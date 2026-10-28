//
//  SevenZipBridge.swift
//  Swift Bridge to native 7-Zip C Core Wrapper
//

import Foundation

public final class SevenZipBridge {
    public static let shared = SevenZipBridge()

    private init() {}

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
                arg.withCString { strdup($0) }
            }

            let code = cArgs.withUnsafeBufferPointer { buf in
                let basePtr = buf.baseAddress.map { UnsafeMutablePointer(mutating: $0) }
                return sz_run(Int32(arguments.count), basePtr, &callbacks)
            }

            // Free argument C strings
            for ptr in cArgs {
                if let p = ptr {
                    free(UnsafeMutableRawPointer(mutating: p))
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

    /// Get localized error text
    public func errorMessage(for exitCode: Int, isRussian: Bool) -> String {
        guard let cStr = sz_get_error_message(Int32(exitCode), isRussian ? 1 : 0) else {
            return isRussian ? "Неизвестная ошибка" : "Unknown error"
        }
        return String(cString: cStr)
    }

    /// Parse archive contents using "l -slt"
    public func listArchive(
        at archiveURL: URL,
        password: String? = nil,
        completion: @escaping (Result<([ArchiveItem], ArchiveInfo), Error>) -> Void
    ) {
        var args = ["7zz", "l", "-slt", "-y"]
        if let pwd = password, !pwd.isEmpty {
            args.append("-p\(pwd)")
        }
        args.append(archiveURL.path)

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
                if code != SZ_OK && code != SZ_WARNING {
                    let errDesc = self.errorMessage(for: code, isRussian: Locale.current.languageCode == "ru")
                    let detailed = errorLines.isEmpty ? errDesc : errorLines.joined(separator: "\n")
                    completion(.failure(NSError(domain: "7Zip", code: code, userInfo: [NSLocalizedDescriptionKey: detailed])))
                    return
                }

                let parsed = self.parseSltOutput(logLines)
                completion(.success(parsed))
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
                    info.rawProperties = currentProperties
                    isHeaderSection = false
                } else if let path = currentProperties["Path"], !path.isEmpty {
                    let isDir = (currentProperties["Folder"] == "+" || currentProperties["Attributes"]?.contains("D") == true)
                    let size = UInt64(currentProperties["Size"] ?? "0") ?? 0
                    let packed = UInt64(currentProperties["Packed Size"] ?? "0") ?? 0
                    let crc = currentProperties["CRC"] ?? ""
                    let method = currentProperties["Method"] ?? ""
                    let attr = currentProperties["Attributes"] ?? ""
                    let encrypted = (currentProperties["Encrypted"] == "+")

                    var modDate: Date? = nil
                    if let modStr = currentProperties["Modified"] {
                        let df = DateFormatter()
                        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
                        modDate = df.date(from: modStr)
                    }

                    let filename = (path as NSString).lastPathComponent
                    let item = ArchiveItem(
                        name: filename.isEmpty ? path : filename,
                        path: path,
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
