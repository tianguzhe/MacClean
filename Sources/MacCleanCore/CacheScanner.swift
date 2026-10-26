import Foundation
import Darwin

public struct CacheScanner: Sendable {
    public init() {}

    public func scan(
        definitions: [CacheDefinition] = CacheCatalog.all,
        home: URL = FileManager.default.homeDirectoryForCurrentUser,
        onResult: @escaping @Sendable (CacheScanResult) async -> Void
    ) async {
        await withTaskGroup(of: CacheScanResult?.self) { group in
            var iterator = definitions.makeIterator()
            for _ in 0..<min(4, definitions.count) {
                if let definition = iterator.next() {
                    group.addTask(priority: .utility) { try? Self.scanDefinition(definition, home: home) }
                }
            }
            while let result = await group.next() {
                if Task.isCancelled { group.cancelAll(); break }
                if let result { await onResult(result) }
                if let definition = iterator.next() {
                    group.addTask(priority: .utility) { try? Self.scanDefinition(definition, home: home) }
                }
            }
        }
    }

    public static func scanDefinition(_ definition: CacheDefinition, home: URL) throws -> CacheScanResult {
        var seenFiles = Set<FileIdentity>()
        var acceptedRoots: [String] = []
        var locations: [CacheLocation] = []
        let homePrefix = home.standardizedFileURL.path + "/"
        // Process parents first so overlapping roots produce stable locations and totals.
        let configuredRoots: Set<URL> = Set(definition.paths.map { home.appendingPathComponent($0).standardizedFileURL })
        let containedRoots = configuredRoots.filter { $0.path.hasPrefix(homePrefix) }
        let roots = containedRoots.sorted { left, right in
            let leftPath = left.path
            let rightPath = right.path
            if leftPath.count == rightPath.count { return leftPath < rightPath }
            return leftPath.count < rightPath.count
        }
        for root in roots {
            try Task.checkCancellation()
            // A catalog entry may overlap another root; never count the same tree twice.
            guard !acceptedRoots.contains(where: { root.path == $0 || root.path.hasPrefix($0 + "/") }) else { continue }
            acceptedRoots.append(root.path)
            locations.append(try scanLocation(root, seenFiles: &seenFiles))
        }
        return CacheScanResult(definitionID: definition.id, locations: locations)
    }

    private struct FileIdentity: Hashable {
        let device: dev_t
        let inode: ino_t
    }

    private static func scanLocation(_ root: URL, seenFiles: inout Set<FileIdentity>) throws -> CacheLocation {
        let manager = FileManager()
        var rootInfo = stat()
        guard lstat(root.path, &rootInfo) == 0 else {
            let errorNumber = errno
            let missing = errorNumber == ENOENT || errorNumber == ENOTDIR
            return CacheLocation(url: root, exists: !missing, bytes: 0, logicalBytes: 0, fileCount: 0,
                                 issues: missing ? [] : [ScanIssue(path: root.path, message: String(cString: strerror(errorNumber)))], largestItems: [])
        }
        // Resolving a configured cache path must never lead into a symlinked project or data tree.
        guard (rootInfo.st_mode & S_IFMT) != S_IFLNK,
              root.resolvingSymlinksInPath().path == root.path else {
            return CacheLocation(url: root, exists: true, bytes: 0, logicalBytes: 0, fileCount: 0,
                                 issues: [ScanIssue(path: root.path, message: "已跳过符号链接，避免扫描目标目录之外的数据。")], largestItems: [])
        }
        var bytes: Int64 = 0
        var logicalBytes: Int64 = 0
        var fileCount = 0
        var issues: [ScanIssue] = []
        var groups: [String: (bytes: Int64, count: Int)] = [:]

        func consume(_ rawURL: URL) {
            // Foundation enumeration can return /private/var for a /var root.
            // Normalize both URLs before deriving a relative child path.
            let url = rawURL.standardizedFileURL
            var info = stat()
            guard lstat(url.path, &info) == 0 else {
                if issues.count < 20 {
                    issues.append(ScanIssue(path: url.path, message: String(cString: strerror(errno))))
                }
                return
            }
            guard (info.st_mode & S_IFMT) == S_IFREG else { return }
            // Single-link files cannot appear in multiple non-overlapping roots.
            if info.st_nlink > 1 {
                let identity = FileIdentity(device: info.st_dev, inode: info.st_ino)
                guard seenFiles.insert(identity).inserted else { return }
            }
            let allocated = Int64(info.st_blocks) * 512
            bytes += allocated
            logicalBytes += Int64(info.st_size)
            fileCount += 1
            let suffix = String(url.path.dropFirst(root.path.count + 1))
            let child = suffix.split(separator: "/").first.map(String.init) ?? url.lastPathComponent
            let groupPath = url.path == root.path ? root.path : root.appendingPathComponent(child).path
            let previous = groups[groupPath] ?? (0, 0)
            groups[groupPath] = (previous.bytes + allocated, previous.count + 1)
        }

        if (rootInfo.st_mode & S_IFMT) == S_IFREG {
            consume(root)
        } else if let enumerator = manager.enumerator(at: root, includingPropertiesForKeys: nil, options: [], errorHandler: { url, error in
            if issues.count < 20 { issues.append(ScanIssue(path: url.path, message: error.localizedDescription)) }
            return !Task.isCancelled
        }) {
            var visited = 0
            for case let url as URL in enumerator {
                visited += 1
                if visited % 64 == 0 { try Task.checkCancellation() }
                consume(url)
            }
        } else {
            issues.append(ScanIssue(path: root.path, message: "无法读取此目录。"))
        }
        try Task.checkCancellation()
        let largest = groups.map { CacheItem(url: URL(fileURLWithPath: $0.key), bytes: $0.value.bytes, fileCount: $0.value.count) }
            .sorted { $0.bytes > $1.bytes }.prefix(12).map { $0 }
        return CacheLocation(url: root, exists: true, bytes: bytes, logicalBytes: logicalBytes,
                             fileCount: fileCount, issues: issues, largestItems: largest)
    }
}
