//
//  CompressionSettings.swift
//  7Zip Desktop-Parity Compression Settings Model
//

import Foundation

public enum ArchiveFormat: String, CaseIterable, Identifiable, Codable {
    case sevenZip = "7z"
    case zip = "zip"
    case tar = "tar"
    case gzip = "gzip"
    case bzip2 = "bzip2"
    case xz = "xz"
    case wim = "wim"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .sevenZip: return "7z"
        case .zip: return "zip"
        case .tar: return "tar"
        case .gzip: return "gzip (.gz)"
        case .bzip2: return "bzip2 (.bz2)"
        case .xz: return "xz"
        case .wim: return "wim"
        }
    }

    public var defaultExtension: String {
        switch self {
        case .sevenZip: return ".7z"
        case .zip: return ".zip"
        case .tar: return ".tar"
        case .gzip: return ".gz"
        case .bzip2: return ".bz2"
        case .xz: return ".xz"
        case .wim: return ".wim"
        }
    }

    public var supportedMethods: [CompressionMethod] {
        switch self {
        case .sevenZip:
            return [.lzma2, .lzma, .ppmd, .bzip2, .copy]
        case .zip:
            return [.deflate, .deflate64, .bzip2, .lzma, .ppmd, .copy]
        case .gzip:
            return [.deflate]
        case .bzip2:
            return [.bzip2]
        case .xz:
            return [.lzma2]
        case .tar, .wim:
            return [.copy]
        }
    }
}

public enum CompressionLevel: Int, CaseIterable, Identifiable, Codable {
    case store = 0
    case fastest = 1
    case fast = 3
    case normal = 5
    case maximum = 7
    case ultra = 9

    public var id: Int { rawValue }

    public var localizedName: String {
        switch self {
        case .store: return NSLocalizedString("level_store", comment: "")
        case .fastest: return NSLocalizedString("level_fastest", comment: "")
        case .fast: return NSLocalizedString("level_fast", comment: "")
        case .normal: return NSLocalizedString("level_normal", comment: "")
        case .maximum: return NSLocalizedString("level_maximum", comment: "")
        case .ultra: return NSLocalizedString("level_ultra", comment: "")
        }
    }
}

public enum CompressionMethod: String, CaseIterable, Identifiable, Codable {
    case lzma2 = "LZMA2"
    case lzma = "LZMA"
    case ppmd = "PPMd"
    case bzip2 = "BZip2"
    case deflate = "Deflate"
    case deflate64 = "Deflate64"
    case copy = "Copy"

    public var id: String { rawValue }

    public var switchValue: String {
        switch self {
        case .lzma2: return "lzma2"
        case .lzma: return "lzma"
        case .ppmd: return "ppmd"
        case .bzip2: return "bzip2"
        case .deflate: return "deflate"
        case .deflate64: return "deflate64"
        case .copy: return "copy"
        }
    }
}

public enum UpdateMode: String, CaseIterable, Identifiable, Codable {
    case addReplace = "add_replace"
    case updateAdd = "update_add"
    case freshen = "freshen"
    case synchronize = "synchronize"

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .addReplace: return NSLocalizedString("update_add_replace", comment: "")
        case .updateAdd: return NSLocalizedString("update_update_add", comment: "")
        case .freshen: return NSLocalizedString("update_freshen", comment: "")
        case .synchronize: return NSLocalizedString("update_synchronize", comment: "")
        }
    }

    public var switchFlag: String {
        switch self {
        case .addReplace: return "-u"
        case .updateAdd: return "-up0q0"
        case .freshen: return "-up0q3"
        case .synchronize: return "-up0q0r2x1y1z1w2"
        }
    }
}

public enum PathMode: String, CaseIterable, Identifiable, Codable {
    case relative = "relative"
    case full = "full"
    case absolute = "absolute"

    public var id: String { rawValue }

    public var localizedName: String {
        switch self {
        case .relative: return NSLocalizedString("path_relative", comment: "")
        case .full: return NSLocalizedString("path_full", comment: "")
        case .absolute: return NSLocalizedString("path_absolute", comment: "")
        }
    }
}

public struct CompressionSettings: Codable, Equatable {
    public var format: ArchiveFormat = .sevenZip
    public var level: CompressionLevel = .normal
    public var method: CompressionMethod = .lzma2
    public var dictionarySizeMB: Int = 32 // in MB
    public var wordSize: Int = 32 // 32, 64, 128, 273
    public var solidBlockSizeMB: Int = 2048 // 0 for non-solid, -1 for Solid
    public var threads: Int = max(1, ProcessInfo.processInfo.activeProcessorCount / 2)
    public var memoryLimitMB: Int = 0 // 0 = default calculated budget

    public var splitVolumeSize: String = "" // "10M", "100M", "700M", "1000M", "4480M" or custom
    public var updateMode: UpdateMode = .addReplace
    public var pathMode: PathMode = .relative

    public var preserveTimestamps: Bool = true
    public var preserveSymlinks: Bool = true
    public var recursive: Bool = true
    public var excludeMask: String = ""
    public var includeMask: String = ""

    public var password: String = ""
    public var confirmPassword: String = ""
    public var encryptFileNames: Bool = false
    public var customParameters: String = ""

    public init() {
        self.threads = max(1, ProcessInfo.processInfo.activeProcessorCount)
    }

    // Live calculation of memory usage for compression in bytes
    public func estimatedCompressionMemoryBytes() -> UInt64 {
        switch method {
        case .lzma2, .lzma:
            let dictBytes = UInt64(dictionarySizeMB) * 1024 * 1024
            let threadCount = UInt64(max(1, threads))
            // 7-Zip formula approx: dictSize * 11.5 * threads (or base dictSize * 11 + thread buffers)
            return dictBytes * 11 + (threadCount * 8 * 1024 * 1024)
        case .ppmd:
            return UInt64(dictionarySizeMB) * 1024 * 1024 + 16 * 1024 * 1024
        case .bzip2:
            return UInt64(max(1, threads)) * 8 * 1024 * 1024
        case .deflate, .deflate64:
            return UInt64(max(1, threads)) * 4 * 1024 * 1024
        case .copy:
            return 2 * 1024 * 1024
        }
    }

    // Live calculation of memory usage for decompression in bytes
    public func estimatedDecompressionMemoryBytes() -> UInt64 {
        switch method {
        case .lzma2, .lzma:
            return UInt64(dictionarySizeMB) * 1024 * 1024 + 2 * 1024 * 1024
        case .ppmd:
            return UInt64(dictionarySizeMB) * 1024 * 1024
        case .bzip2:
            return 4 * 1024 * 1024
        case .deflate, .deflate64, .copy:
            return 2 * 1024 * 1024
        }
    }

    // Generates exact 7-Zip CLI arguments
    public func buildArguments(archivePath: String, inputPaths: [String]) -> [String] {
        var args: [String] = ["7zz", "a"]

        // Format switch
        args.append("-t\(format.rawValue)")

        // Level
        args.append("-mx=\(level.rawValue)")

        // Method & Dictionary
        if format == .sevenZip || format == .xz {
            args.append("-m0=\(method.switchValue)")
            if method == .lzma2 || method == .lzma {
                args.append("-md=\(dictionarySizeMB)m")
                args.append("-mfb=\(wordSize)")
                if solidBlockSizeMB == 0 {
                    args.append("-ms=off")
                } else if solidBlockSizeMB == -1 {
                    args.append("-ms=on")
                } else {
                    args.append("-ms=\(solidBlockSizeMB)m")
                }
            }
        } else if format == .zip {
            if method != .deflate {
                args.append("-mm=\(method.switchValue)")
            }
        }

        // Multithreading
        args.append("-mmt=\(threads)")

        // Memory limit switch
        if memoryLimitMB > 0 {
            args.append("-mmemuse=\(memoryLimitMB)m")
        }

        // Split to volumes
        if !splitVolumeSize.isEmpty && splitVolumeSize != "none" {
            args.append("-v\(splitVolumeSize)")
        }

        // Encryption
        if !password.isEmpty {
            args.append("-p\(password)")
            if format == .sevenZip && encryptFileNames {
                args.append("-mhe=on")
            } else if format == .zip {
                args.append("-mem=AES256")
            }
        }

        // Masks & recursion
        if recursive {
            args.append("-r")
        }
        if !excludeMask.isEmpty {
            for m in excludeMask.split(separator: " ") {
                args.append("-x!\(m)")
            }
        }
        if !includeMask.isEmpty {
            for m in includeMask.split(separator: " ") {
                args.append("-i!\(m)")
            }
        }

        // Custom parameters
        if !customParameters.isEmpty {
            for param in customParameters.split(separator: " ") {
                args.append(String(param))
            }
        }

        // Always assume Yes to prompts from CLI since UI handles confirmations
        args.append("-y")

        // Archive path
        args.append(archivePath)

        // Inputs
        for input in inputPaths {
            args.append(input)
        }

        return args
    }

    // Built-in presets
    public static var presetFast: CompressionSettings {
        var s = CompressionSettings()
        s.format = .sevenZip
        s.level = .fastest
        s.method = .lzma2
        s.dictionarySizeMB = 16
        s.wordSize = 32
        return s
    }

    public static var presetNormal: CompressionSettings {
        var s = CompressionSettings()
        s.format = .sevenZip
        s.level = .normal
        s.method = .lzma2
        s.dictionarySizeMB = 32
        s.wordSize = 64
        return s
    }

    public static var presetMaximum: CompressionSettings {
        var s = CompressionSettings()
        s.format = .sevenZip
        s.level = .maximum
        s.method = .lzma2
        s.dictionarySizeMB = 64
        s.wordSize = 128
        return s
    }

    public static var presetMaxEncrypted: CompressionSettings {
        var s = CompressionSettings()
        s.format = .sevenZip
        s.level = .maximum
        s.method = .lzma2
        s.dictionarySizeMB = 64
        s.wordSize = 128
        s.encryptFileNames = true
        return s
    }
}
