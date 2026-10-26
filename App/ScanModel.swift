import SwiftUI
import MacCleanCore

@MainActor @Observable
final class ScanModel {
    var results: [String: CacheScanResult] = [:]
    var disk: DiskSnapshot?
    var diskError: String?
    var isScanning = false
    var isCancelling = false
    var hasScanned = false
    var wasCancelled = false
    var finishedAt: Date?
    var scanStartedAt: Date?
    var definitions: [CacheDefinition] = CacheCatalog.all
    var discoveryIssues: [ScanIssue] = []
    var isDiscovering = false
    private var scanTask: Task<Void, Never>?

    init() { refreshDisk() }

    var totalBytes: Int64 { bytes(for: .cache) }
    var editorDataBytes: Int64 { bytes(for: .applicationSupport) }
    var editorDataCount: Int {
        definitions.filter { $0.kind == .applicationSupport && results[$0.id]?.isPresent == true }.count
    }
    var analyzedBytes: Int64 { totalBytes + editorDataBytes }
    var presentCount: Int { results.values.filter(\.isPresent).count }
    var fileCount: Int { results.values.reduce(0) { $0 + $1.fileCount } }
    var detectedCount: Int { definitions.filter { $0.kind == .cache && results[$0.id]?.isPresent == true }.count }
    var issueCount: Int { results.values.filter { !$0.issues.isEmpty }.count + discoveryIssues.count }
    var progress: Double { Double(results.count) / Double(max(1, definitions.count)) }
    var sortedDefinitions: [CacheDefinition] {
        definitions.filter { $0.kind == .cache }.sorted {
            let left = results[$0.id]?.bytes ?? 0
            let right = results[$1.id]?.bytes ?? 0
            return left == right ? $0.name.localizedStandardCompare($1.name) == .orderedAscending : left > right
        }
    }

    func bytes(for category: DeveloperCategory) -> Int64 {
        bytes(for: .cache, category: category)
    }

    func totalBytes(for category: DeveloperCategory) -> Int64 {
        bytes(for: .cache, category: category) + bytes(for: .applicationSupport, category: category)
    }

    func bytes(for kind: StorageKind, category: DeveloperCategory? = nil) -> Int64 {
        definitions.filter { $0.kind == kind && (category == nil || $0.category == category) }
            .reduce(0) { $0 + (results[$1.id]?.bytes ?? 0) }
    }

    var statusText: String {
        if isDiscovering { return "正在发现开发工具…" }
        if isScanning { return "正在扫描 · \(results.count) / \(definitions.count) 项" }
        if wasCancelled { return "扫描已停止 · 已完成 \(results.count) 项" }
        if let finishedAt { return "更新于 \(finishedAt.formatted(date: .omitted, time: .shortened))" }
        return "准备扫描"
    }

    func refreshDisk() {
        do {
            disk = try DiskSnapshot.read(at: FileManager.default.homeDirectoryForCurrentUser)
            diskError = nil
        } catch { diskError = error.localizedDescription }
    }

    func startScan() {
        guard !isScanning else { return }
        results = [:]
        isScanning = true
        isCancelling = false
        wasCancelled = false
        scanStartedAt = .now
        isDiscovering = true
        discoveryIssues = []
        refreshDisk()
        scanTask = Task { [weak self] in
            let catalog = await Task.detached(priority: .utility) { CacheCatalog.discover() }.value
            guard let self else { return }
            self.definitions = catalog.definitions
            self.discoveryIssues = catalog.issues
            self.isDiscovering = false
            if !Task.isCancelled {
                await CacheScanner().scan(definitions: catalog.definitions) { [weak self] result in
                    await self?.receive(result)
                }
            }
            self.wasCancelled = Task.isCancelled
            self.isScanning = false
            self.isCancelling = false
            self.hasScanned = true
            self.finishedAt = Task.isCancelled ? nil : .now
            self.refreshDisk()
            self.scanTask = nil
        }
    }

    private func receive(_ result: CacheScanResult) {
        results[result.id] = result
    }

    func cancelScan() {
        guard isScanning else { return }
        isCancelling = true
        scanTask?.cancel()
    }
}
