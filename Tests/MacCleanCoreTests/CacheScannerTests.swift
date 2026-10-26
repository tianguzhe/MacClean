import Foundation
import Testing
@testable import MacCleanCore

struct CacheScannerTests {
    private func temporaryHome() throws -> URL {
        let url = FileManager.default.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent("MacCleanTests-" + UUID().uuidString)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func definition(paths: [String]) -> CacheDefinition {
        .init(id: "test", name: "Test", subtitle: "", category: .apple, symbol: "folder", paths: paths, explanation: "")
    }

    @Test func countsNestedFilesAndIncludesHiddenFiles() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let cache = home.appendingPathComponent("cache/child")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data(repeating: 7, count: 9000).write(to: cache.appendingPathComponent("data"))
        try Data(repeating: 3, count: 2000).write(to: home.appendingPathComponent("cache/.hidden"))
        let result = try CacheScanner.scanDefinition(definition(paths: ["cache"]), home: home)
        #expect(result.fileCount == 2)
        #expect(result.logicalBytes == 11000)
        #expect(result.bytes > 0)
        #expect(Set(result.largestItems.map { $0.url.lastPathComponent }) == ["child", ".hidden"])
        #expect(result.issues.isEmpty)
    }

    @Test func neverFollowsSymbolicLinks() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home.appendingPathComponent("cache"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: home.appendingPathComponent("source"), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 8192).write(to: home.appendingPathComponent("source/important"))
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent("cache/link"), withDestinationURL: home.appendingPathComponent("source"))
        let result = try CacheScanner.scanDefinition(definition(paths: ["cache"]), home: home)
        #expect(result.fileCount == 0)
        #expect(result.bytes == 0)
        let linkedRoot = try CacheScanner.scanDefinition(definition(paths: ["cache/link"]), home: home)
        #expect(linkedRoot.fileCount == 0)
        #expect(!linkedRoot.issues.isEmpty)
    }

    @Test func deduplicatesHardLinksAndOverlappingRoots() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home.appendingPathComponent("cache/nested"), withIntermediateDirectories: true)
        let file = home.appendingPathComponent("cache/nested/data")
        try Data(repeating: 1, count: 8192).write(to: file)
        try FileManager.default.linkItem(at: file, to: home.appendingPathComponent("cache/linked"))
        let result = try CacheScanner.scanDefinition(definition(paths: ["cache", "cache/nested"]), home: home)
        #expect(result.fileCount == 1)
        #expect(result.logicalBytes == 8192)
        #expect(result.locations.count == 1)
    }

    @Test func missingDirectoriesAreNotAccessErrors() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let result = try CacheScanner.scanDefinition(definition(paths: ["missing"]), home: home)
        #expect(!result.isPresent)
        #expect(result.issues.isEmpty)
    }

    @Test func overlappingRootsAreIndependentOfCatalogOrder() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        try FileManager.default.createDirectory(at: home.appendingPathComponent("cache/nested"), withIntermediateDirectories: true)
        try Data(repeating: 1, count: 8192).write(to: home.appendingPathComponent("cache/nested/data"))
        let result = try CacheScanner.scanDefinition(definition(paths: ["cache/nested", "cache", "cache/./"]), home: home)
        #expect(result.locations.count == 1)
        #expect(result.locations.first?.url == home.appendingPathComponent("cache"))
        #expect(result.fileCount == 1)
        #expect(result.logicalBytes == 8192)
    }

    @Test func standaloneArchiveKeepsItsActualPath() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let archive = home.appendingPathComponent("package.conda")
        try Data(repeating: 2, count: 16000).write(to: archive)
        let result = try CacheScanner.scanDefinition(definition(paths: ["package.conda"]), home: home)
        #expect(result.largestItems.first?.url == archive)
        #expect(result.logicalBytes == 16000)
        #expect(result.fileCount == 1)
    }

    @Test func sparseFilesUseAllocatedSpace() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let sparse = home.appendingPathComponent("sparse")
        #expect(FileManager.default.createFile(atPath: sparse.path, contents: nil))
        let handle = try FileHandle(forWritingTo: sparse)
        try handle.truncate(atOffset: 4 * 1024 * 1024)
        try handle.close()
        let result = try CacheScanner.scanDefinition(definition(paths: ["sparse"]), home: home)
        #expect(result.logicalBytes == 4 * 1024 * 1024)
        #expect(result.bytes < result.logicalBytes)
    }

    @Test func rejectsPathsOutsideHome() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let result = try CacheScanner.scanDefinition(definition(paths: ["../outside"]), home: home)
        #expect(result.locations.isEmpty)
    }

    @Test func cancellationDoesNotReportACompleteScan() async throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try CacheScanner.scanDefinition(definition(paths: ["missing"]), home: home)
        }
        do {
            _ = try await task.value
            Issue.record("Cancelled scan unexpectedly completed")
        } catch is CancellationError {
            // Cancellation must reach the caller instead of appearing as an empty scan.
        }
    }

    @Test func catalogDoesNotTreatUserEnvironmentsAsCaches() {
        #expect(Set(CacheCatalog.all.map(\.id)).count == CacheCatalog.all.count)
        #expect(!CacheCatalog.all.flatMap(\.paths).contains { $0.contains("virtualenvs") || $0.contains("Archives") || $0.contains("CoreSimulator/Devices") })
    }

    @Test func discoversStudioVersionsWithoutIncludingOtherGoogleApplications() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let support = home.appendingPathComponent("Library/Application Support/Google")
        for name in ["AndroidStudio2026.2.1", "AndroidStudioPreview2024.3", "AndroidStudio2024.3.2-backup", "Chrome", "AndroidStudioProjects", "AndroidStudio2026.2.1-junk"] {
            try FileManager.default.createDirectory(at: support.appendingPathComponent(name), withIntermediateDirectories: true)
        }
        try Data().write(to: support.appendingPathComponent("AndroidStudio2023.1"))
        let cache = home.appendingPathComponent("Library/Caches/Google/AndroidStudio2026.2.1")
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)

        let discovery = CacheCatalog.discover(home: home)
        let versions = discovery.definitions.filter { $0.kind == .applicationSupport }
        #expect(versions.count == 3)
        #expect(versions.allSatisfy { $0.category == .editors })
        #expect(versions.contains { $0.name == "Android Studio Preview 2024.3" })
        #expect(versions.contains { $0.name == "Android Studio 2024.3.2 · 备份" })
        #expect(discovery.definitions.contains { $0.kind == .cache && $0.paths == ["Library/Caches/Google/AndroidStudio2026.2.1"] })
        #expect(discovery.definitions.filter { $0.id.hasPrefix("android-studio-") }.allSatisfy { $0.category == .editors })
        #expect(!discovery.definitions.flatMap(\.paths).contains { $0.contains("Chrome") || $0.contains("AndroidStudioProjects") || $0.contains("junk") || $0.contains("AndroidStudio2023.1") })
        #expect(Set(discovery.definitions.map(\.id)).count == discovery.definitions.count)
        #expect(discovery.issues.isEmpty)
    }

    @Test func applicationSupportAndCachesHaveSeparateScanRootsAndTotals() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let support = home.appendingPathComponent("Library/Application Support/Google/AndroidStudio2026.2.1")
        let cache = home.appendingPathComponent("Library/Caches/Google/AndroidStudio2026.2.1")
        try FileManager.default.createDirectory(at: support.appendingPathComponent("plugins"), withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: cache, withIntermediateDirectories: true)
        try Data(repeating: 1, count: 15000).write(to: support.appendingPathComponent("plugins/plugin.jar"))
        try Data(repeating: 2, count: 30000).write(to: cache.appendingPathComponent("index"))
        let definitions = CacheCatalog.discover(home: home).definitions.filter { $0.id.hasPrefix("android-studio-") }
        let version = try #require(definitions.first { $0.kind == .applicationSupport })
        let cached = try #require(definitions.first { $0.kind == .cache })
        let versionResult = try CacheScanner.scanDefinition(version, home: home)
        let cacheResult = try CacheScanner.scanDefinition(cached, home: home)
        #expect(versionResult.logicalBytes == 15000)
        #expect(cacheResult.logicalBytes == 30000)
        #expect(versionResult.largestItems.first?.url.lastPathComponent == "plugins")
        #expect(versionResult.locations.first?.url != cacheResult.locations.first?.url)
    }

    @Test func discoverySkipsLinkedVersionDirectories() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        let support = home.appendingPathComponent("Library/Application Support/Google")
        let external = home.appendingPathComponent("project")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: external, withIntermediateDirectories: true)
        try FileManager.default.createSymbolicLink(at: support.appendingPathComponent("AndroidStudio2026.1"), withDestinationURL: external)
        let discovery = CacheCatalog.discover(home: home)
        #expect(discovery.definitions.filter { $0.kind == .applicationSupport }.isEmpty)
        #expect(discovery.issues.count == 1)
    }

    @Test func discoveryReportsInaccessibleGoogleDirectories() throws {
        let home = try temporaryHome()
        let support = home.appendingPathComponent("Library/Application Support/Google")
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: support.path)
            try? FileManager.default.removeItem(at: home)
        }
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: support.path)
        let discovery = CacheCatalog.discover(home: home)
        #expect(discovery.definitions.filter { $0.kind == .applicationSupport }.isEmpty)
        #expect(!discovery.issues.isEmpty)
    }

    @Test func personalEditorDataDoesNotReceiveCacheCleanupCommands() throws {
        let source = try #require(CacheCatalog.all.first { $0.id == "pip" })
        let support = CacheDefinition(id: source.id, name: source.name, subtitle: source.subtitle,
                                      category: .editors, symbol: source.symbol, paths: source.paths,
                                      explanation: source.explanation, kind: .applicationSupport)
        #expect(!source.cleanupCommands.isEmpty)
        #expect(support.cleanupCommands.isEmpty)
    }

    @Test func condaDiscoveryOnlyIncludesArchivesAndIndexMetadata() throws {
        let home = try temporaryHome()
        defer { try? FileManager.default.removeItem(at: home) }
        for path in ["miniforge3/pkgs/cache", "miniforge3/pkgs/numpy/lib", "miniforge3/envs/work", ".cache/huggingface"] {
            try FileManager.default.createDirectory(at: home.appendingPathComponent(path), withIntermediateDirectories: true)
        }
        for path in ["miniforge3/pkgs/numpy.conda", "miniforge3/pkgs/openssl.tar.bz2", "miniforge3/pkgs/cache/index.json"] {
            try Data(repeating: 3, count: 1000).write(to: home.appendingPathComponent(path))
        }
        for path in ["miniforge3/pkgs/numpy/lib/live.py", "miniforge3/envs/work/important", ".cache/huggingface/token"] {
            try Data(repeating: 9, count: 4000).write(to: home.appendingPathComponent(path))
        }
        try FileManager.default.createSymbolicLink(at: home.appendingPathComponent("miniforge3/pkgs/linked.conda"), withDestinationURL: home.appendingPathComponent("miniforge3/envs/work/important"))
        let discovery = CacheCatalog.discover(home: home)
        let conda = try #require(discovery.definitions.first { $0.id == "conda" })
        let result = try CacheScanner.scanDefinition(conda, home: home)
        #expect(result.fileCount == 3)
        #expect(result.logicalBytes == 3000)
        #expect(!conda.paths.contains { $0.contains("envs") || $0.contains("linked.conda") || $0.contains("/numpy/") })
        let huggingface = try #require(discovery.definitions.first { $0.id == "huggingface" })
        #expect(try CacheScanner.scanDefinition(huggingface, home: home).fileCount == 0)
        #expect(!conda.cleanupCommands.contains { $0.command.contains("--force-pkgs-dirs") || $0.command.contains("--packages") })
    }

    @Test func catalogRootsDoNotOverlapAcrossToolsOrContainWholeEnvironments() {
        let roots = CacheCatalog.all.flatMap { definition in definition.paths.map { (definition.id, $0) } }
        for (index, left) in roots.enumerated() {
            #expect(![".npm", ".cargo", ".rustup", ".android", ".docker", ".kube", ".cache/huggingface", ".pub-cache", ".nvm", ".local/share/mise"].contains(left.1))
            for right in roots.dropFirst(index + 1) where left.0 != right.0 {
                #expect(left.1 != right.1 && !left.1.hasPrefix(right.1 + "/") && !right.1.hasPrefix(left.1 + "/"))
            }
        }
        #expect(CacheCatalog.all.compactMap(\.documentationURL).allSatisfy { $0.scheme == "https" })
    }
}
