import Foundation

public struct ScanIssue: Identifiable, Sendable {
    public var id: String { path + message }
    public let path: String
    public let message: String
    public let category: DeveloperCategory?
    public let kind: StorageKind?

    public init(path: String, message: String, category: DeveloperCategory? = nil, kind: StorageKind? = nil) {
        self.path = path
        self.message = message
        self.category = category
        self.kind = kind
    }
}

public struct CacheItem: Identifiable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let bytes: Int64
    public let fileCount: Int
}

public struct CacheLocation: Identifiable, Sendable {
    public var id: String { url.path }
    public let url: URL
    public let exists: Bool
    public let bytes: Int64
    public let logicalBytes: Int64
    public let fileCount: Int
    public let issues: [ScanIssue]
    public let largestItems: [CacheItem]
}

public struct CacheScanResult: Identifiable, Sendable {
    public var id: String { definitionID }
    public let definitionID: String
    public let locations: [CacheLocation]
    public var bytes: Int64 { locations.reduce(0) { $0 + $1.bytes } }
    public var logicalBytes: Int64 { locations.reduce(0) { $0 + $1.logicalBytes } }
    public var fileCount: Int { locations.reduce(0) { $0 + $1.fileCount } }
    public var isPresent: Bool { locations.contains { $0.exists } }
    public var issues: [ScanIssue] { locations.flatMap(\.issues) }
    public var largestItems: [CacheItem] {
        locations.flatMap(\.largestItems).sorted { $0.bytes > $1.bytes }.prefix(12).map { $0 }
    }
}

public struct DiskSnapshot: Sendable {
    public let name: String
    public let totalBytes: Int64
    public let availableBytes: Int64
    public var usedBytes: Int64 { max(0, totalBytes - availableBytes) }
    public var usedFraction: Double { totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) : 0 }

    public static func read(at url: URL) throws -> DiskSnapshot {
        let values = try url.resourceValues(forKeys: [.volumeNameKey, .volumeTotalCapacityKey, .volumeAvailableCapacityKey])
        guard let total = values.volumeTotalCapacity, let available = values.volumeAvailableCapacity else {
            throw CocoaError(.fileReadUnknown)
        }
        return DiskSnapshot(name: values.volumeName ?? "Macintosh HD", totalBytes: Int64(total), availableBytes: Int64(available))
    }
}
