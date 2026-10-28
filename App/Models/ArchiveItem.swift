//
//  ArchiveItem.swift
//  7Zip Model for archive item entry
//

import Foundation

public struct ArchiveItem: Identifiable, Hashable {
    public let id = UUID()
    public var name: String
    public var path: String
    public var size: UInt64
    public var packedSize: UInt64
    public var modifiedDate: Date?
    public var crc: String
    public var method: String
    public var attributes: String
    public var isDir: Bool
    public var isEncrypted: Bool

    public init(
        name: String,
        path: String,
        size: UInt64 = 0,
        packedSize: UInt64 = 0,
        modifiedDate: Date? = nil,
        crc: String = "",
        method: String = "",
        attributes: String = "",
        isDir: Bool = false,
        isEncrypted: Bool = false
    ) {
        self.name = name
        self.path = path
        self.size = size
        self.packedSize = packedSize
        self.modifiedDate = modifiedDate
        self.crc = crc
        self.method = method
        self.attributes = attributes
        self.isDir = isDir
        self.isEncrypted = isEncrypted
    }

    public func formattedSize(binary: Bool = true) -> String {
        if isDir { return "--" }
        return ByteCountFormatter.string(
            fromByteCount: Int64(size),
            countStyle: binary ? .binary : .decimal
        )
    }

    public func formattedPackedSize(binary: Bool = true) -> String {
        if isDir || packedSize == 0 { return "--" }
        return ByteCountFormatter.string(
            fromByteCount: Int64(packedSize),
            countStyle: binary ? .binary : .decimal
        )
    }

    public func formattedDate() -> String {
        guard let d = modifiedDate else { return "--" }
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        return f.string(from: d)
    }
}
