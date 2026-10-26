import Foundation

public struct CleanupCommand: Identifiable, Sendable {
    public var id: String { command }
    public let title: String
    public let command: String
    public let note: String
    public let documentationURL: URL
}

extension CacheDefinition {
    /// Display guidance only. Application Support data never receives cache commands.
    public var cleanupCommands: [CleanupCommand] {
        guard kind == .cache else { return [] }
        return CleanupCommand.catalog[id] ?? []
    }
}

extension CleanupCommand {
    private static func entry(_ title: String, _ command: String, _ note: String, _ documentation: String) -> CleanupCommand {
        CleanupCommand(title: title, command: command, note: note, documentationURL: URL(string: documentation)!)
    }

    fileprivate static let catalog: [String: [CleanupCommand]] = [
        "npm": [entry("清空 npm 下载缓存", "npm cache clean --force",
                      "清空 npm 当前配置的包缓存，后续安装会重新下载依赖。npm 要求使用 --force 才允许清空缓存。",
                      "https://docs.npmjs.com/cli/commands/npm-cache")],
        "pnpm": [entry("清理未引用的包", "pnpm store prune",
                       "移除共享 store 中未被引用的包，正在使用的包会保留；释放量取决于可移除的内容。",
                       "https://pnpm.io/cli/store")],
        "yarn": [
            entry("Yarn 1.x · 全局缓存", "yarn cache clean",
                  "适用于 Yarn Classic，清空全局下载缓存。请使用与你的项目对应的 Yarn 版本。",
                  "https://classic.yarnpkg.com/lang/en/docs/cli/cache/"),
            entry("Yarn 2+ · 全局缓存", "yarn cache clean --mirror",
                  "适用于 Yarn Berry，在使用对应 Yarn 版本的项目目录执行。--mirror 指向全局缓存。",
                  "https://yarnpkg.com/cli/cache/clean")
        ],
        "bun": [entry("清空 Bun 安装缓存", "bun pm cache rm",
                      "清空 Bun 的全局安装缓存，后续安装需要重新下载包。",
                      "https://bun.com/docs/cli/pm")],
        "pip": [entry("清空 pip 缓存", "python3 -m pip cache purge",
                      "移除此 Python 对应 pip 的 HTTP 与 wheel 缓存。使用特定环境时，将 python3 换成对应的 Python 解释器。",
                      "https://pip.pypa.io/en/stable/cli/pip_cache/")],
        "uv": [entry("清空 uv 缓存", "uv cache clean",
                     "移除 uv 缓存中的所有条目，后续依赖操作会重新下载或构建。使用中的条目由 uv 的检查机制处理。",
                     "https://docs.astral.sh/uv/reference/cli/#uv-cache-clean")],
        "poetry": [entry("清理 PyPI 仓库缓存", "poetry cache clear pypi --all",
                         "清理名为 pypi 的仓库缓存，其他仓库需要替换名称；artifacts 目录中的归档可能保留。",
                         "https://python-poetry.org/docs/cli/#cache-clear")],
        "homebrew": [
            entry("先预览清理范围", "brew cleanup --prune=all --dry-run",
                  "只列出将移除的内容，可先核对下载缓存与旧版本软件的清理范围。",
                  "https://docs.brew.sh/Manpage#cleanup-options-formulacask-"),
            entry("执行 Homebrew 清理", "brew cleanup --prune=all",
                  "清理下载缓存、过期锁文件和不再需要的旧版本软件。此命令的范围包含旧软件版本，请先查看上方预览。",
                  "https://docs.brew.sh/Manpage#cleanup-options-formulacask-")
        ],
        "cocoapods": [entry("清空 CocoaPods 下载缓存", "pod cache clean --all",
                           "清空所有 Pod 的下载缓存，项目中的 Pods 目录保持独立；下一次安装可能重新下载。",
                           "https://guides.cocoapods.org/terminal/commands.html#pod_cache_clean")],
        "swiftpm": [entry("清理 SwiftPM 全局仓库缓存", "swift package purge-cache",
                         "清理 Swift Package Manager 的全局仓库缓存。其他类型的临时文件可能保留。",
                         "https://www.swift.org/documentation/")],
        "go": [entry("清空 Go 构建缓存", "go clean -cache",
                     "清理 Go 编译缓存，后续构建会重新编译；模块下载缓存由 Go 的另一项操作管理。",
                     "https://pkg.go.dev/cmd/go#hdr-Remove_object_files_and_cached_files")],
        "composer": [entry("清空 Composer 缓存", "composer clear-cache",
                          "清理 Composer 的包、仓库元数据及其他缓存，后续依赖操作会重新下载。",
                          "https://getcomposer.org/doc/03-cli.md#clear-cache-clearcache-cc")],
        "nuget": [entry("清空 NuGet 全局包缓存", "dotnet nuget locals global-packages --clear",
                        "清理 .NET 当前配置的全局包目录，后续构建需要重新还原依赖。请先结束正在使用这些包的构建。",
                        "https://learn.microsoft.com/dotnet/core/tools/dotnet-nuget-locals")],
        "playwright": [entry("移除缓存的测试浏览器", "npx --no-install playwright uninstall --all",
                             "在已安装 Playwright 的项目目录执行，移除所有 Playwright 版本下载的浏览器。再次测试前运行 npx playwright install。",
                             "https://playwright.dev/docs/browsers#uninstall-browsers")],
        "npm-exec": [entry("清理 npx 临时包缓存", "npm cache npx rm",
                           "适用于提供 npm cache npx 子命令的新版 npm，移除 npx 缓存中的所有条目。旧版 npm 不支持此命令；请先结束正在运行的 npx 任务。",
                           "https://docs.npmjs.com/cli/commands/npm-cache")],
        "nvm": [entry("清理 Node.js 下载包", "nvm cache clear",
                      "在已加载 nvm 的终端中执行。清空下载缓存，已安装的 Node.js 版本保留；请先结束正在进行的 nvm 安装。",
                      "https://github.com/nvm-sh/nvm#problems")],
        "deno": [
            entry("预览 Deno 缓存清理", "deno clean --dry-run",
                  "需要提供 clean 子命令的 Deno 版本，只列出清理范围。", "https://docs.deno.com/runtime/reference/cli/clean/"),
            entry("清理 Deno 模块缓存", "deno clean",
                  "移除当前 DENO_DIR 下的全局模块缓存，后续执行会重新下载和编译。离线运行需要的依赖也会移除。",
                  "https://docs.deno.com/runtime/reference/cli/clean/")
        ],
        "cypress": [entry("清空 Cypress 运行器缓存", "npx --no-install cypress cache clear",
                          "在已安装 Cypress 的项目目录执行。清空所有版本的运行器缓存，下次测试前需要运行 npx cypress install。",
                          "https://docs.cypress.io/app/references/command-line#cypress-cache-clear")],
        "conda": [
            entry("预览 Conda 下载缓存清理", "conda clean --tarballs --index-cache --dry-run",
                  "列出将清理的下载归档与仓库索引，不移除已解包的包和环境。",
                  "https://docs.conda.io/projects/conda/en/stable/commands/clean.html"),
            entry("清理 Conda 下载缓存", "conda clean --tarballs --index-cache",
                  "清理当前 Conda 配置下的归档与索引，不使用 --packages 或 --force-pkgs-dirs。命令可能处理扫描范围外的自定义或系统级包缓存。",
                  "https://docs.conda.io/projects/conda/en/stable/commands/clean.html")
        ],
        "huggingface": [
            entry("预览过期模型修订", "hf cache prune --dry-run",
                  "需要支持 cache prune 的新版 huggingface_hub CLI；列出未被分支或标签引用的修订及下载残留。",
                  "https://huggingface.co/docs/huggingface_hub/guides/manage-cache#clean-your-cache"),
            entry("清理未引用的模型缓存", "hf cache prune",
                  "清理未引用的修订、残留下载与无引用数据块。请先核对预览，固定使用旧 commit 的离线任务可能仍需这些文件。",
                  "https://huggingface.co/docs/huggingface_hub/guides/manage-cache#clean-your-cache")
        ],
        "dart-pub": [entry("清空 Pub 系统缓存", "dart pub cache clean",
                           "命令覆盖整个 Pub 系统缓存，比本页统计范围更广，可能同时移除全局激活的工具；之后可能需要重新激活。Flutter 用户可使用对应 SDK 中的 dart。",
                           "https://dart.dev/tools/pub/cmd/pub-cache#clearing-the-global-system-cache")],
        "go-modules": [entry("清空 Go 模块缓存", "go clean -modcache",
                             "删除当前 GOMODCACHE 的全部下载依赖与解包源码，后续构建需要联网重新下载；先结束正在使用模块缓存的构建。",
                             "https://pkg.go.dev/cmd/go#hdr-Remove_object_files_and_cached_files")],
        "ccache": [entry("清空编译结果缓存", "ccache --clear",
                         "清理当前 ccache 缓存中的编译结果，保留配置；后续编译需要重新生成缓存。",
                         "https://ccache.dev/manual/latest.html#_options")],
        "mise": [entry("清理 mise 缓存", "mise cache clear",
                       "清理当前 mise 的缓存，包括版本元数据和任务缓存。已安装工具保留；命令的缓存范围可能随 mise 版本变化。",
                       "https://mise.jdx.dev/cli/cache/clear.html")],
        "nuget-http": [entry("清理 NuGet HTTP 缓存", "dotnet nuget locals http-cache --clear",
                             "清理当前配置的仓库 HTTP 响应缓存，不清理全局已解包依赖。",
                             "https://learn.microsoft.com/dotnet/core/tools/dotnet-nuget-locals")],
        "nuget-plugins": [entry("清理 NuGet 插件缓存", "dotnet nuget locals plugins-cache --clear",
                                "清理插件操作缓存，保留插件本体；请先结束正在进行的 NuGet 操作。",
                                "https://learn.microsoft.com/dotnet/core/tools/dotnet-nuget-locals")]
    ]
}
