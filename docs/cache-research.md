# 开发工具隐藏目录调研

核对日期：2026-10-26。读取官方文档与工具源码，默认目录由应用离线检测；不执行任何清理命令。默认缓存检测从 26 项扩展至 43 项，另动态发现 Android Studio 各版本目录。

| 工具 | 本次新增的用户目录（均相对 `~/`） | 核对来源与处理方式 |
| --- | --- | --- |
| npm / npx | `.npm/_npx` | [npm cache](https://docs.npmjs.com/cli/commands/npm-cache)：与 `_cacache` 独立；新版 npm 支持 `npm cache npx rm`。 |
| NVM | `.nvm/.cache/bin`、`.nvm/.cache/src` | [官方源码](https://github.com/nvm-sh/nvm/blob/master/nvm.sh)：只统计下载缓存，排除已安装的 Node.js。 |
| Deno | `Library/Caches/deno`、`.cache/deno` | [deno info](https://docs.deno.com/runtime/reference/cli/info/)、[deno clean](https://docs.deno.com/runtime/reference/cli/clean/)：支持预览；离线模块也在缓存内。 |
| Cypress | `Library/Caches/Cypress` | [安装与缓存](https://docs.cypress.io/app/references/advanced-installation)、[清理命令](https://docs.cypress.io/app/references/command-line#cypress-cache-clear)：重新测试前需安装运行器。 |
| Puppeteer | `.cache/puppeteer` | [官方配置](https://pptr.dev/guides/configuration)：19+ 的测试浏览器下载目录。 |
| Coursier | `Library/Caches/Coursier/v1`、`.coursier/cache/v1` | [官方缓存说明](https://get-coursier.io/docs/cache)：当前与旧版默认位置。 |
| Apache Ivy | `.ivy2/cache` | [Ivy cache settings](https://ant.apache.org/ivy/history/latest-milestone/settings/caches.html)：排除 `.ivy2/local` 的本地发布构件。 |
| Conda / Miniforge | `.conda/pkgs` 及常见用户安装前缀的 `pkgs` 中的 `cache`、`.conda` 和 `.tar.bz2` 文件 | [Conda clean](https://docs.conda.io/projects/conda/en/stable/commands/clean.html)：仅发现归档与索引；排除解包目录和环境，不使用 `--force-pkgs-dirs`。 |
| Hugging Face | `.cache/huggingface/hub` | [缓存管理](https://huggingface.co/docs/huggingface_hub/guides/manage-cache)：下载模型、数据集与修订；提供 prune 预览，排除 token 与上传暂存。 |
| Dart / Flutter Pub | `.pub-cache/hosted`、`hosted-hashes`、`git` | [环境变量](https://dart.dev/tools/pub/environment-variables)、[清理命令](https://dart.dev/tools/pub/cmd/pub-cache)：统计排除全局工具，但清理命令会覆盖整个 Pub 缓存，界面明确说明。 |
| Go Modules | `go/pkg/mod` | [Go command](https://pkg.go.dev/cmd/go)：默认 GOPATH 的模块缓存，支持 `go clean -modcache`。 |
| ccache | `Library/Caches/ccache`、`.ccache` | [官方手册](https://ccache.dev/manual/latest.html)：兼容旧位置，命令保留配置。 |
| sccache | `Library/Caches/Mozilla.sccache` | [官方本地缓存文档](https://github.com/mozilla/sccache/blob/main/docs/Local.md)：不能把 `--zero-stats` 当作清缓存；只提供目录依据。 |
| mise | `Library/Caches/mise`、`.cache/mise` | [目录说明](https://mise.jdx.dev/directories.html)、[cache clear](https://mise.jdx.dev/cli/cache/clear.html)：排除已安装工具。 |
| NuGet HTTP | `.local/share/NuGet/v3-cache` | [NuGet 缓存管理](https://learn.microsoft.com/nuget/consume-packages/managing-the-global-packages-and-cache-folders)：与已解包全局依赖分开。 |
| NuGet 插件缓存 | `.local/share/NuGet/plugins-cache` | 同上，提供对应 `dotnet nuget locals` 命令。 |
| Helm | `Library/Caches/helm`、`.cache/helm` | [Helm 环境](https://helm.sh/docs/helm/helm_env)：兼容常见版本，排除 kubeconfig、认证配置及集群数据。 |

已有 Cargo 项目同时补充 `.cargo/registry/src`、`registry/index`、`git/db`、`git/checkouts`，依据 [Cargo Home](https://doc.rust-lang.org/cargo/guide/cargo-home.html)。排除 credentials、配置、bin 和 Rust 工具链；Git 检出可能含本地修改，因此不提供整目录删除命令。

所有命令仅供复制，工具实际使用的自定义路径可能与扫描路径不同。缓存占用不等于可释放空间，模型缓存与依赖源码可能是离线工作所需数据。

## 已调查但不作为缓存统计的目录

| 目录或环境 | 原因 / 可用的工具入口 |
| --- | --- |
| Docker Desktop 的 `Docker.raw`、Podman / Colima 虚拟磁盘 | 同时包含镜像、容器、卷与业务数据，不能把整个虚拟盘归为缓存。[Docker 官方建议](https://docs.docker.com/engine/manage-resources/pruning/)先运行 `docker system df -v` 查看，再按用途使用 builder / image 等 prune；应用不执行这些命令。 |
| `.android/avd`、Android SDK 系统镜像、CoreSimulator Devices | 包含运行环境及设备数据，使用 SDK Manager、Device Manager 或 Xcode 管理。 |
| `.rustup/toolchains`、`.nvm/versions`、`.local/share/mise` | 已安装工具链，清理会影响开发环境。 |
| Conda `envs`、`pkgs` 中的解包目录、Poetry virtualenvs | 是运行环境或可能通过链接支撑运行环境，不能整目录按下载缓存处理。 |
| `.m2` / `.ivy2/local`、`.cargo/credentials*`、`.kube`、Hugging Face token | 包含本地构件、密钥或认证配置。Maven 仅扫描 repository，并注明本地 install 构件可能无法重新下载。 |
| `.sbt` 整目录、编辑器 User / History / workspaceStorage | 混有配置、插件、草稿、会话和历史；不按通用缓存处理。Android Studio 应用支持资料仍单独标记在代码编辑器中。 |
| 项目内 `node_modules`、`target`、`.build`、虚拟环境 | 本次未递归搜索用户项目。删除项目依赖应结合项目与锁文件判断。 |

应用当前检测用户主目录下的默认和常见兼容位置，不读取 shell 启动文件，不执行工具查询命令，不解析认证配置。系统级安装和自定义环境变量路径不在本版检测范围内。
