import Foundation

public enum DeveloperCategory: String, CaseIterable, Identifiable, Sendable {
    case apple, javascript, android, python, packages, editors

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .apple: "Apple 开发"
        case .javascript: "JavaScript"
        case .android: "JVM"
        case .python: "Python"
        case .packages: "包管理器"
        case .editors: "代码编辑器"
        }
    }

    public var symbol: String {
        switch self {
        case .apple: "hammer"
        case .javascript: "curlybraces"
        case .android: "square.stack.3d.up"
        case .python: "terminal"
        case .packages: "shippingbox"
        case .editors: "chevron.left.forwardslash.chevron.right"
        }
    }
}

public enum StorageKind: String, Sendable {
    case cache, applicationSupport
}

public struct CacheDefinition: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    public let subtitle: String
    public let category: DeveloperCategory
    public let symbol: String
    public let paths: [String]
    public let explanation: String
    public let kind: StorageKind
    public let documentationURL: URL?

    public init(id: String, name: String, subtitle: String, category: DeveloperCategory,
                symbol: String, paths: [String], explanation: String, kind: StorageKind = .cache,
                documentation: String? = nil) {
        self.id = id
        self.name = name
        self.subtitle = subtitle
        self.category = category
        self.symbol = symbol
        self.paths = paths
        self.explanation = explanation
        self.kind = kind
        self.documentationURL = documentation.flatMap(URL.init(string:))
    }
}

public struct CatalogDiscovery: Sendable {
    public let definitions: [CacheDefinition]
    public let issues: [ScanIssue]
}

public enum CacheCatalog {
    /// Discover version-specific directories on every scan, including future IDE versions.
    /// Application Support stores settings and plugins, so it must not enter cache totals.
    public static func discover(home: URL = FileManager.default.homeDirectoryForCurrentUser) -> CatalogDiscovery {
        let manager = FileManager()
        var definitions = all
        var issues: [ScanIssue] = []
        for (relativeRoot, kind) in [
            ("Library/Application Support/Google", StorageKind.applicationSupport),
            ("Library/Caches/Google", StorageKind.cache)
        ] {
            let root = home.appendingPathComponent(relativeRoot).standardizedFileURL
            guard root.resolvingSymlinksInPath().path == root.path else {
                issues.append(ScanIssue(path: root.path, message: "已跳过符号链接目录。", category: .editors, kind: kind))
                continue
            }
            do {
                let children = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                for child in children.sorted(by: { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedDescending }) {
                    guard let version = studioVersion(child.lastPathComponent) else { continue }
                    do {
                        let values = try child.resourceValues(forKeys: [.isDirectoryKey, .isSymbolicLinkKey])
                        guard values.isSymbolicLink != true else {
                            issues.append(ScanIssue(path: child.path, message: "已跳过符号链接目录。", category: .editors, kind: kind))
                            continue
                        }
                        guard values.isDirectory == true else { continue }
                        let isCache = kind == .cache
                        let variant = version.preview ? "Preview" : (version.backup ? "备份" : "正式版")
                        let name = "Android Studio \(version.preview ? "Preview " : "")\(version.number)\(version.backup ? " · 备份" : "")"
                        definitions.append(CacheDefinition(
                            id: "android-studio-\(kind.rawValue)-\(child.lastPathComponent)",
                            name: name,
                            subtitle: isCache ? "\(variant) · IDE 索引与缓存" : "\(variant) · 配置与插件",
                            category: .editors, symbol: isCache ? "square.stack.3d.up.fill" : "clock.arrow.circlepath",
                            paths: [relativeRoot + "/" + child.lastPathComponent],
                            explanation: isCache
                                ? "此版本 Android Studio 的 IDE 索引与缓存。目录中也可能含本地历史记录；重新索引无法恢复这些历史。版本号不表示该版本已经停用。"
                                : "此版本 Android Studio 的应用支持目录，可能包含设置、插件、草稿与历史数据。这里按编辑器资料统计，包含的配置和插件应结合使用情况判断。目录存在和版本较旧都不能说明它已停用；备份目录也可能仍有保留价值。",
                            kind: kind, documentation: "https://developer.android.com/studio/intro/studio-config#directories"
                        ))
                    } catch { issues.append(ScanIssue(path: child.path, message: error.localizedDescription, category: .editors, kind: kind)) }
                }
            } catch {
                let nsError = error as NSError
                if nsError.domain != NSCocoaErrorDomain || nsError.code != CocoaError.fileReadNoSuchFile.rawValue {
                    issues.append(ScanIssue(path: root.path, message: error.localizedDescription, category: .editors, kind: kind))
                }
            }
        }
        // Only package archives and index metadata qualify as Conda cache here.
        // Extracted packages may back live environments through links.
        var archives: [String] = []
        for relativeRoot in condaPackageRoots {
            let root = home.appendingPathComponent(relativeRoot).standardizedFileURL
            guard root.resolvingSymlinksInPath().path == root.path else {
                issues.append(ScanIssue(path: root.path, message: "已跳过符号链接目录。", category: .python, kind: .cache))
                continue
            }
            do {
                let children = try manager.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                for child in children where child.lastPathComponent.hasSuffix(".conda") || child.lastPathComponent.hasSuffix(".tar.bz2") {
                    let values = try child.resourceValues(forKeys: [.isRegularFileKey, .isSymbolicLinkKey])
                    if values.isRegularFile == true && values.isSymbolicLink != true {
                        archives.append(relativeRoot + "/" + child.lastPathComponent)
                    }
                }
            } catch {
                let nsError = error as NSError
                if nsError.domain != NSCocoaErrorDomain || nsError.code != CocoaError.fileReadNoSuchFile.rawValue {
                    issues.append(ScanIssue(path: root.path, message: error.localizedDescription, category: .python, kind: .cache))
                }
            }
        }
        if let index = definitions.firstIndex(where: { $0.id == "conda" }) {
            let source = definitions[index]
            definitions[index] = CacheDefinition(id: source.id, name: source.name, subtitle: source.subtitle,
                category: source.category, symbol: source.symbol, paths: source.paths + archives.sorted(),
                explanation: source.explanation, documentation: source.documentationURL?.absoluteString)
        }
        return CatalogDiscovery(definitions: definitions, issues: issues)
    }

    private static let condaPackageRoots = [
        ".conda/pkgs", "miniconda3/pkgs", "anaconda3/pkgs", "miniforge3/pkgs",
        "mambaforge/pkgs", "opt/miniconda3/pkgs", "opt/anaconda3/pkgs"
    ]

    private static func studioVersion(_ name: String) -> (number: String, preview: Bool, backup: Bool)? {
        let preview = name.hasPrefix("AndroidStudioPreview")
        let prefix = preview ? "AndroidStudioPreview" : "AndroidStudio"
        guard name.hasPrefix(prefix) else { return nil }
        let suffix = String(name.dropFirst(prefix.count))
        guard suffix.range(of: #"^\d{4}(?:\.\d+)+(?:-backup(?:[-.][A-Za-z0-9._-]+)?)?$"#, options: .regularExpression) != nil else { return nil }
        return (suffix.components(separatedBy: "-backup")[0], preview, suffix.contains("-backup"))
    }

    public static let all: [CacheDefinition] = [
        .init(id: "xcode-derived", name: "Xcode", subtitle: "Derived Data", category: .apple,
              symbol: "hammer.fill", paths: ["Library/Developer/Xcode/DerivedData"],
              explanation: "项目编译产物、索引与中间文件。Xcode 会在下一次构建时重新生成；首次构建与索引可能需要更久。"),
        .init(id: "xcode-cache", name: "Xcode 缓存", subtitle: "IDE 与下载缓存", category: .apple,
              symbol: "hammer.fill", paths: ["Library/Caches/com.apple.dt.Xcode"],
              explanation: "Xcode 使用的临时缓存。这里只统计缓存目录，不包含 Archives、设备支持文件与项目源码。"),
        .init(id: "simulator", name: "Simulator", subtitle: "模拟器共享缓存", category: .apple,
              symbol: "iphone", paths: ["Library/Developer/CoreSimulator/Caches"],
              explanation: "CoreSimulator 的共享缓存。不包含模拟器设备、运行时或模拟器中的应用数据。部分目录可能需要额外的系统访问权限。"),
        .init(id: "swiftpm", name: "Swift Package Manager", subtitle: "Swift 包下载缓存", category: .apple,
              symbol: "shippingbox.fill", paths: ["Library/Caches/org.swift.swiftpm", ".swiftpm/cache"],
              explanation: "Swift Package Manager 下载的包与仓库缓存。项目内的 .build 目录不在本次扫描范围中。"),
        .init(id: "cocoapods", name: "CocoaPods", subtitle: "Pod 依赖缓存", category: .apple,
              symbol: "shippingbox.fill", paths: ["Library/Caches/CocoaPods"],
              explanation: "CocoaPods 缓存的依赖包。项目 Pods 目录和本地私有仓库不包含在内。"),
        .init(id: "npm", name: "npm", subtitle: "包内容寻址缓存", category: .javascript,
              symbol: "shippingbox.fill", paths: [".npm/_cacache"],
              explanation: "npm 下载的包内容缓存。不包含项目的 node_modules、全局安装的包或 npm 配置。"),
        .init(id: "pnpm", name: "pnpm", subtitle: "共享包存储", category: .javascript,
              symbol: "square.grid.2x2.fill", paths: ["Library/pnpm/store", ".local/share/pnpm/store"],
              explanation: "pnpm 的共享依赖存储。文件可能通过硬链接或 APFS 克隆与项目共享，统计占用不等于可释放空间。自定义 store-dir 不包含在内。"),
        .init(id: "yarn", name: "Yarn", subtitle: "全局依赖缓存", category: .javascript,
              symbol: "shippingbox.fill", paths: ["Library/Caches/Yarn", ".cache/yarn", ".yarn/berry/cache"],
              explanation: "Yarn Classic 和 Berry 的常见全局缓存。项目内 .yarn/cache 及自定义缓存路径不包含在内。"),
        .init(id: "bun", name: "Bun", subtitle: "安装包缓存", category: .javascript,
              symbol: "bolt.fill", paths: [".bun/install/cache"],
              explanation: "Bun 下载的依赖包缓存。与项目文件共享的磁盘块可能使实际可释放空间小于统计值。"),
        .init(id: "node-gyp", name: "node-gyp", subtitle: "Node.js 编译头文件", category: .javascript,
              symbol: "wrench.and.screwdriver.fill", paths: ["Library/Caches/node-gyp", ".cache/node-gyp"],
              explanation: "编译原生 Node.js 扩展时下载的头文件。需要时 node-gyp 会重新下载。"),
        .init(id: "playwright", name: "Playwright", subtitle: "测试浏览器缓存", category: .javascript,
              symbol: "globe", paths: ["Library/Caches/ms-playwright"],
              explanation: "Playwright 下载的测试浏览器。再次运行测试前可能需要重新安装对应浏览器。"),
        .init(id: "gradle", name: "Gradle", subtitle: "构建与依赖缓存", category: .android,
              symbol: "square.stack.3d.up.fill", paths: [".gradle/caches"],
              explanation: "Gradle 的依赖、转换与构建缓存。不包含项目源码、Gradle 配置和 Android SDK。"),
        .init(id: "gradle-wrapper", name: "Gradle Wrapper", subtitle: "Gradle 发行版缓存", category: .android,
              symbol: "arrow.down.square.fill", paths: [".gradle/wrapper/dists"],
              explanation: "Gradle Wrapper 下载的发行版。项目下次使用对应版本时可以重新下载。"),
        .init(id: "android", name: "Android", subtitle: "Android 构建缓存", category: .android,
              symbol: "app.dashed", paths: [".android/cache", ".android/build-cache"],
              explanation: "Android 工具的常见构建缓存。不包含 AVD 虚拟设备、签名密钥和 SDK 系统镜像。"),
        .init(id: "maven", name: "Maven", subtitle: "本地依赖仓库", category: .android,
              symbol: "shippingbox.fill", paths: [".m2/repository"],
              explanation: "Maven 本地依赖仓库。可能包含通过 install 安装且无法从远端恢复的本地构件，应结合项目情况判断。"),
        .init(id: "pip", name: "pip", subtitle: "Python 包缓存", category: .python,
              symbol: "terminal.fill", paths: ["Library/Caches/pip", ".cache/pip"],
              explanation: "pip 的 HTTP 响应和 wheel 缓存。不包含虚拟环境、已安装的 Python 包与项目源码。"),
        .init(id: "uv", name: "uv", subtitle: "Python 构建与下载缓存", category: .python,
              symbol: "bolt.fill", paths: [".cache/uv", "Library/Caches/uv"],
              explanation: "uv 的包下载与构建缓存。缓存中的文件可能与虚拟环境共享磁盘块。"),
        .init(id: "poetry", name: "Poetry", subtitle: "包与仓库缓存", category: .python,
              symbol: "text.book.closed.fill", paths: ["Library/Caches/pypoetry/cache", "Library/Caches/pypoetry/artifacts"],
              explanation: "Poetry 下载的包与仓库元数据。特意排除 pypoetry/virtualenvs，避免将虚拟环境当作缓存。"),
        .init(id: "homebrew", name: "Homebrew", subtitle: "软件包与下载缓存", category: .packages,
              symbol: "mug.fill", paths: ["Library/Caches/Homebrew"],
              explanation: "Homebrew 的下载、Bottle 与源代码归档缓存。不包含已安装的软件。自定义 HOMEBREW_CACHE 不包含在内。"),
        .init(id: "cargo", name: "Cargo", subtitle: "Rust 包、索引与依赖源码", category: .packages,
              symbol: "gearshape.fill", paths: [".cargo/registry/cache", ".cargo/registry/src", ".cargo/registry/index", ".cargo/git/db", ".cargo/git/checkouts"],
              explanation: "Cargo 下载的 crate 归档、解包源码、索引和 Git 依赖。离线构建会使用这些数据；Git 检出中也可能有本地修改。不包含 credentials、配置、Rust 工具链、项目 target 和已安装程序。",
              documentation: "https://doc.rust-lang.org/cargo/guide/cargo-home.html"),
        .init(id: "go", name: "Go", subtitle: "构建缓存", category: .packages,
              symbol: "terminal.fill", paths: ["Library/Caches/go-build"],
              explanation: "Go 默认的编译缓存。自定义 GOCACHE 与 GOPATH 的模块存储不包含在内。"),
        .init(id: "composer", name: "Composer", subtitle: "PHP 依赖缓存", category: .packages,
              symbol: "shippingbox.fill", paths: ["Library/Caches/composer", ".composer/cache", ".cache/composer"],
              explanation: "Composer 下载的 PHP 依赖与元数据。不包含项目 vendor 和 Composer 配置。"),
        .init(id: "nuget", name: "NuGet", subtitle: ".NET 全局包缓存", category: .packages,
              symbol: "shippingbox.fill", paths: [".nuget/packages"],
              explanation: "NuGet 默认的全局包缓存。不包含 .NET SDK。使用这些包的项目再次构建时可能需要还原依赖。"),
        .init(id: "vscode", name: "Visual Studio Code", subtitle: "编辑器与扩展缓存", category: .editors,
              symbol: "chevron.left.forwardslash.chevron.right", paths: ["Library/Application Support/Code/Cache", "Library/Application Support/Code/CachedData", "Library/Application Support/Code/GPUCache", "Library/Application Support/Code/CachedExtensionVSIXs"],
              explanation: "VS Code 的代码、GPU 与扩展安装包缓存。不包含扩展安装目录、设置、工作区和本地历史记录。"),
        .init(id: "cursor", name: "Cursor", subtitle: "编辑器缓存", category: .editors,
              symbol: "cursorarrow", paths: ["Library/Application Support/Cursor/Cache", "Library/Application Support/Cursor/CachedData", "Library/Application Support/Cursor/GPUCache", "Library/Application Support/Cursor/CachedExtensionVSIXs"],
              explanation: "Cursor 的临时与安装包缓存。不包含聊天记录、设置、扩展和工作区数据。"),
        .init(id: "jetbrains", name: "JetBrains", subtitle: "IDE 索引与缓存", category: .editors,
              symbol: "square.stack.fill", paths: ["Library/Caches/JetBrains"],
              explanation: "JetBrains IDE 的系统目录，包括索引与缓存，也可能含本地历史记录和插件数据。重新索引不能恢复本地历史。不包含设置与项目源码。",
              documentation: "https://www.jetbrains.com/help/idea/directories-used-by-the-ide-to-store-settings-caches-plugins-and-logs.html"),
        .init(id: "npm-exec", name: "npm / npx", subtitle: "临时执行的包缓存", category: .javascript,
              symbol: "terminal.fill", paths: [".npm/_npx"],
              explanation: "npm exec 和 npx 为运行命令下载的临时依赖。与 npm 的 _cacache 分开统计，不包含全局安装包和 npm 登录配置。",
              documentation: "https://docs.npmjs.com/cli/commands/npm-cache"),
        .init(id: "nvm", name: "NVM", subtitle: "Node.js 安装包下载缓存", category: .javascript,
              symbol: "arrow.down.circle", paths: [".nvm/.cache/bin", ".nvm/.cache/src"],
              explanation: "NVM 下载的 Node.js 二进制与源码归档。不包含 .nvm/versions 中已安装的运行时、别名和 shell 配置。",
              documentation: "https://github.com/nvm-sh/nvm#problems"),
        .init(id: "deno", name: "Deno", subtitle: "模块与编译缓存", category: .javascript,
              symbol: "terminal.fill", paths: ["Library/Caches/deno", ".cache/deno"],
              explanation: "Deno 缓存的远程模块、npm 依赖与编译产物。不包含 .deno/bin 中已安装的程序；离线执行会依赖缓存。自定义 DENO_DIR 不包含在内。",
              documentation: "https://docs.deno.com/runtime/reference/cli/info/"),
        .init(id: "cypress", name: "Cypress", subtitle: "测试运行器下载缓存", category: .javascript,
              symbol: "checkmark.circle", paths: ["Library/Caches/Cypress"],
              explanation: "各版本 Cypress 下载的运行器。清理后测试前需要重新执行 cypress install，不包含项目测试代码。",
              documentation: "https://docs.cypress.io/app/references/advanced-installation"),
        .init(id: "puppeteer", name: "Puppeteer", subtitle: "测试浏览器下载缓存", category: .javascript,
              symbol: "globe", paths: [".cache/puppeteer"],
              explanation: "Puppeteer 19+ 下载的 Chrome 等测试浏览器。清理后需要重新下载；不包含浏览器个人资料与项目文件。",
              documentation: "https://pptr.dev/guides/configuration"),
        .init(id: "coursier", name: "Coursier", subtitle: "Scala / JVM 依赖缓存", category: .android,
              symbol: "shippingbox.fill", paths: ["Library/Caches/Coursier/v1", ".coursier/cache/v1"],
              explanation: "Coursier、Scala CLI 和新版 sbt 下载的依赖。清理后需要重新下载；不包含已安装 JDK 和项目源码。",
              documentation: "https://get-coursier.io/docs/cache"),
        .init(id: "ivy", name: "Apache Ivy", subtitle: "JVM 依赖下载缓存", category: .android,
              symbol: "shippingbox.fill", paths: [".ivy2/cache"],
              explanation: "Ivy 与旧版 sbt 使用的依赖缓存。不包含 .ivy2/local 中可能只有本机存在的已发布构件；离线构建可能需要此缓存。",
              documentation: "https://ant.apache.org/ivy/history/latest-milestone/settings/caches.html"),
        .init(id: "conda", name: "Conda", subtitle: "包归档与仓库索引", category: .python,
              symbol: "shippingbox.fill", paths: condaPackageRoots.map { $0 + "/cache" },
              explanation: "常见用户级 Conda、Miniconda 和 Miniforge 安装中的索引，以及扫描时发现的 .conda / .tar.bz2 下载归档。排除解包目录、envs 和解释器，避免把运行环境当作下载缓存。系统级安装与自定义 pkgs_dirs 不在范围内。",
              documentation: "https://docs.conda.io/projects/conda/en/stable/commands/clean.html"),
        .init(id: "huggingface", name: "Hugging Face", subtitle: "模型与数据集下载缓存", category: .python,
              symbol: "sparkles", paths: [".cache/huggingface/hub"],
              explanation: "从 Hub 下载的模型、数据集和历史修订，可能占用较大空间。离线推理需要保留使用中的模型；不包含 token、用户配置、上传暂存数据和本地训练输出。自定义 HF_HOME / HF_HUB_CACHE 不包含在内。",
              documentation: "https://huggingface.co/docs/huggingface_hub/guides/manage-cache"),
        .init(id: "dart-pub", name: "Dart / Flutter Pub", subtitle: "Dart 包与 Git 依赖缓存", category: .packages,
              symbol: "shippingbox.fill", paths: [".pub-cache/hosted", ".pub-cache/hosted-hashes", ".pub-cache/git"],
              explanation: "Dart 与 Flutter Pub 下载的包、校验数据和 Git 依赖。缓存范围排除 bin、global_packages 和 SDK；dart pub cache clean 命令清理范围更广，可能影响全局激活工具。",
              documentation: "https://dart.dev/tools/pub/environment-variables"),
        .init(id: "go-modules", name: "Go Modules", subtitle: "Go 模块依赖缓存", category: .packages,
              symbol: "shippingbox.fill", paths: ["go/pkg/mod"],
              explanation: "默认 GOPATH 下的模块下载和解包缓存。不包含 go/bin 中安装的程序；下次构建可能需要重新下载。自定义 GOPATH / GOMODCACHE 不包含在内。",
              documentation: "https://pkg.go.dev/cmd/go#hdr-Remove_object_files_and_cached_files"),
        .init(id: "ccache", name: "ccache", subtitle: "C / C++ 编译缓存", category: .packages,
              symbol: "gearshape.2", paths: ["Library/Caches/ccache", ".ccache"],
              explanation: "C / C++ 编译结果缓存，兼容旧版 .ccache 路径。目录可能含少量统计与配置文件，建议使用 ccache --clear 清理编译条目。",
              documentation: "https://ccache.dev/manual/latest.html"),
        .init(id: "sccache", name: "sccache", subtitle: "Rust / C / C++ 编译缓存", category: .packages,
              symbol: "gearshape.2", paths: ["Library/Caches/Mozilla.sccache"],
              explanation: "sccache 在 macOS 上的默认本地编译缓存。不包含 Rust 工具链和远程缓存；自定义 SCCACHE_DIR 不包含在内。",
              documentation: "https://github.com/mozilla/sccache/blob/main/docs/Local.md"),
        .init(id: "mise", name: "mise", subtitle: "运行时管理器缓存", category: .packages,
              symbol: "slider.horizontal.3", paths: ["Library/Caches/mise", ".cache/mise"],
              explanation: "mise 的版本元数据、下载与任务缓存。不包含 .local/share/mise 中安装的工具、插件和 shims。",
              documentation: "https://mise.jdx.dev/directories.html"),
        .init(id: "nuget-http", name: "NuGet HTTP", subtitle: ".NET 仓库响应缓存", category: .packages,
              symbol: "shippingbox.fill", paths: [".local/share/NuGet/v3-cache"],
              explanation: "NuGet 包源 HTTP 响应缓存，与全局已解包依赖目录分开统计。不包含 .NET SDK 和 nuget.config。",
              documentation: "https://learn.microsoft.com/nuget/consume-packages/managing-the-global-packages-and-cache-folders"),
        .init(id: "nuget-plugins", name: "NuGet 插件缓存", subtitle: ".NET 插件操作缓存", category: .packages,
              symbol: "shippingbox.fill", paths: [".local/share/NuGet/plugins-cache"],
              explanation: "NuGet 插件的操作缓存，不包含插件本体、SDK 和个人配置。",
              documentation: "https://learn.microsoft.com/nuget/consume-packages/managing-the-global-packages-and-cache-folders"),
        .init(id: "helm", name: "Helm", subtitle: "Chart 与仓库索引缓存", category: .packages,
              symbol: "shippingbox.fill", paths: ["Library/Caches/helm", ".cache/helm"],
              explanation: "Helm 常见版本的 Chart 下载和仓库索引缓存。不包含 .kube 凭据、Helm 配置和集群内的数据。",
              documentation: "https://helm.sh/docs/helm/helm_env")
    ]
}
