//
//  ArchiveInfo.swift
//  7Zip Model for archive metadata
//

import Foundation

public struct ArchiveInfo: Hashable {
    public var format: String = ""
    public var physicalSize: UInt64 = 0
    public var headersSize: UInt64 = 0
    public var isSolid: Bool = false
    public var method: String = ""
    public var blocksCount: Int = 0
    public var filesCount: Int = 0
    public var foldersCount: Int = 0
    public var rawProperties: [String: String] = [:]

    public init(
        format: String = "7z",
        physicalSize: UInt64 = 0,
        headersSize: UInt64 = 0,
        isSolid: Bool = false,
        method: String = "",
        blocksCount: Int = 0,
        filesCount: Int = 0,
        foldersCount: Int = 0,
        rawProperties: [String: String] = [:]
    ) {
        self.format = format
        self.physicalSize = physicalSize
        self.headersSize = headersSize
        self.isSolid = isSolid
        self.method = method
        self.blocksCount = blocksCount
        self.filesCount = filesCount
        self.foldersCount = foldersCount
        self.rawProperties = rawProperties
    }

    public func formattedPhysicalSize(binary: Bool = true) -> String {
        return ByteCountFormatter.string(
            fromByteCount: Int64(physicalSize),
            countStyle: binary ? .binary : .decimal
        )
    }

    public func formattedHeadersSize(binary: Bool = true) -> String {
        return ByteCountFormatter.string(
            fromByteCount: Int64(headersSize),
            countStyle: binary ? .binary : .decimal
        )
    }
}
