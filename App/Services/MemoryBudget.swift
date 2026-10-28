//
//  MemoryBudget.swift
//  7Zip iOS Jetsam Memory Budget Calculation
//

import Foundation

public struct MemoryBudget {
    /// Safe available memory on current iOS device in bytes (via os_proc_available_memory)
    public static func availableMemory() -> UInt64 {
        return sz_get_available_memory()
    }

    /// Safe compression memory budget (70% of available memory to prevent Jetsam kills)
    public static func safeCompressionBudget() -> UInt64 {
        let avail = availableMemory()
        return UInt64(Double(avail) * 0.70)
    }

    /// Formatted description of available memory (e.g. "1.2 GB")
    public static func formattedAvailable() -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(availableMemory()), countStyle: .binary)
    }

    /// Formatted description of safe budget
    public static func formattedSafeBudget() -> String {
        return ByteCountFormatter.string(fromByteCount: Int64(safeCompressionBudget()), countStyle: .binary)
    }

    /// Checks if requested settings fit in safe Jetsam memory budget
    public static func checkSafety(settings: CompressionSettings) -> (isSafe: Bool, required: UInt64, available: UInt64) {
        let required = settings.estimatedCompressionMemoryBytes()
        let safe = safeCompressionBudget()
        return (required <= safe, required, availableMemory())
    }

    /// Auto-reduces dictionary size and/or thread count to fit within safe budget
    public static func autoReduce(settings: inout CompressionSettings) {
        let safeBudget = safeCompressionBudget()

        // List of common dictionary sizes in descending order
        let dictSizes = [1536, 1024, 768, 512, 384, 256, 192, 128, 96, 64, 48, 32, 24, 16, 12, 8, 4, 2, 1]

        // 1. Try reducing dictionary size first
        for size in dictSizes {
            if size < settings.dictionarySizeMB {
                settings.dictionarySizeMB = size
                if settings.estimatedCompressionMemoryBytes() <= safeBudget {
                    return
                }
            }
        }

        // 2. If still exceeding budget, reduce threads to 1 or 2
        while settings.threads > 1 && settings.estimatedCompressionMemoryBytes() > safeBudget {
            settings.threads -= 1
        }
    }
}
