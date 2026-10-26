import SwiftUI
import AppKit
import MacCleanCore

struct CacheDetailView: View {
    let definition: CacheDefinition
    let result: CacheScanResult?
    let isScanning: Bool
    @State private var showsExplanation = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 13) {
                ToolIcon(definition: definition, size: 46)
                VStack(alignment: .leading, spacing: 6) {
                    Text(definition.name).font(.system(size: 20, weight: .semibold)).tracking(-0.4)
                    HStack(spacing: 8) {
                        KindBadge(kind: definition.kind)
                        Text(definition.category.title).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                    }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark").font(.system(size: 10, weight: .semibold)).foregroundStyle(Palette.secondary)
                        .frame(width: 27, height: 27).background(Palette.background, in: Circle())
                }.buttonStyle(.plain).keyboardShortcut(.cancelAction).help("关闭")
            }.padding(25)
            Rectangle().fill(Palette.line).frame(height: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 25) {
                    sizeOverview
                    if !definition.cleanupCommands.isEmpty { cleanupSection }
                    directorySection
                    if let result, !result.largestItems.isEmpty { largestSection(result) }
                    DisclosureGroup(isExpanded: $showsExplanation) {
                        Text(definition.explanation).font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(5)
                            .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 10).textSelection(.enabled)
                    } label: {
                        Label("关于这些文件", systemImage: "info.circle").font(.system(size: 12, weight: .medium))
                    }.tint(Palette.secondary)
                    if let result, !result.issues.isEmpty { issuesSection(result) }
                }.padding(25)
            }.scrollIndicators(.hidden)
            Rectangle().fill(Palette.line).frame(height: 1)
            HStack {
                Text("按实际分配空间统计，可能包含共享磁盘块。")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.defaultAction).controlSize(.regular)
            }.padding(.horizontal, 25).frame(height: 55)
        }
        .frame(width: 640, height: 720).background(.white).foregroundStyle(Palette.ink).tint(Palette.accent)
    }

    private var cleanupSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("清理命令").font(.system(size: 13, weight: .semibold))
                Spacer()
                Label("复制后在终端运行", systemImage: "terminal")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
            ForEach(definition.cleanupCommands) { command in
                CleanupCommandCard(command: command)
            }
            Text("命令使用工具当前的缓存配置，自定义位置可能与本次扫描范围不同。")
                .font(.system(size: 10)).foregroundStyle(Palette.secondary).lineSpacing(3)
        }
    }

    private var sizeOverview: some View {
        HStack(alignment: .center, spacing: 25) {
            VStack(alignment: .leading, spacing: 8) {
                Text("磁盘占用").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                Text(result.map { StorageFormat.string($0.bytes) } ?? "—")
                    .font(.system(size: 35, weight: .medium, design: .rounded)).tracking(-0.8).monospacedDigit()
            }
            Spacer(minLength: 0)
            VStack(alignment: .trailing, spacing: 12) {
                detailMetric("逻辑大小", value: result.map { StorageFormat.string($0.logicalBytes) } ?? "—")
                detailMetric("文件数量", value: result.map { $0.fileCount.formatted() } ?? "—")
            }
        }.padding(20).background(Palette.background, in: RoundedRectangle(cornerRadius: 12))
    }

    private var directorySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("所在目录").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(definition.paths.count) 个位置").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                if let url = definition.documentationURL {
                    Link(destination: url) {
                        Label("目录依据", systemImage: "arrow.up.right").font(.system(size: 10))
                    }.foregroundStyle(Palette.accent)
                }
            }
            ForEach(definition.paths, id: \.self) { path in
                let url = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(path)
                let location = result?.locations.first { $0.url.path == url.path }
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .top, spacing: 9) {
                        Image(systemName: "folder").font(.system(size: 13)).foregroundStyle(Palette.accent)
                        Text("~/" + path).font(.system(size: 11, design: .monospaced)).foregroundStyle(Palette.ink.opacity(0.85))
                            .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                    }
                    HStack {
                        Text(locationStatus(location)).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        Spacer()
                        if location?.exists == true {
                            Button { NSWorkspace.shared.activateFileViewerSelecting([url]) } label: {
                                Label("在 Finder 中显示", systemImage: "arrow.up.right")
                                    .font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.accent)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(15).background(.white, in: RoundedRectangle(cornerRadius: 10))
                .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Palette.line))
            }
        }
    }

    private func largestSection(_ result: CacheScanResult) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("占用明细").font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("最大的 \(result.largestItems.count) 个直接子项").font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }.padding(.bottom, 4)
            ForEach(result.largestItems) { item in
                Button { NSWorkspace.shared.activateFileViewerSelecting([item.url]) } label: {
                    HStack(spacing: 11) {
                        Image(systemName: "doc.on.doc").font(.system(size: 14)).foregroundStyle(Palette.secondary)
                            .frame(width: 28, height: 30)
                        VStack(alignment: .leading, spacing: 7) {
                            HStack {
                                Text(item.url.lastPathComponent).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                                Spacer(minLength: 8)
                                Text(StorageFormat.string(item.bytes)).font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
                            }
                            GeometryReader { proxy in
                                Capsule().fill(Palette.line.opacity(0.7))
                                    .overlay(alignment: .leading) {
                                        Capsule().fill(Palette.accent.opacity(0.55))
                                            .frame(width: max(2, proxy.size.width * min(1, Double(item.bytes) / Double(max(1, result.bytes)))))
                                    }
                            }.frame(height: 3)
                        }
                        Image(systemName: "arrow.up.right").font(.system(size: 9)).foregroundStyle(Palette.secondary).padding(.leading, 5)
                    }.padding(.vertical, 9).contentShape(Rectangle())
                }.buttonStyle(.plain).help("\(item.fileCount.formatted()) 个文件 · 在 Finder 中显示")
            }
        }
    }

    private func issuesSection(_ result: CacheScanResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("有内容未能读取", systemImage: "exclamationmark.circle").font(.system(size: 12, weight: .medium)).foregroundStyle(Color(hex: 0xB38A53))
            Text("当前占用仅包含已读取的文件。若系统限制了访问，可在系统设置的“完全磁盘访问权限”中允许 MacClean 后重新扫描。")
                .font(.system(size: 11)).foregroundStyle(Palette.secondary).lineSpacing(4)
            ForEach(Array(result.issues.prefix(5))) { issue in
                Text(StorageFormat.path(URL(fileURLWithPath: issue.path)) + "\n" + issue.message)
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(Palette.secondary).textSelection(.enabled)
            }
        }.padding(15).background(Color(hex: 0xFAF6EF), in: RoundedRectangle(cornerRadius: 10))
    }

    private func locationStatus(_ location: CacheLocation?) -> String {
        guard let location else { return isScanning ? "等待扫描" : "尚未扫描" }
        if !location.exists { return "未发现此目录" }
        if !location.issues.isEmpty { return "部分内容未读取" }
        return "已读取 · \(location.fileCount.formatted()) 个文件"
    }

    private func detailMetric(_ title: String, value: String) -> some View {
        HStack(spacing: 14) {
            Text(title).font(.system(size: 10)).foregroundStyle(Palette.secondary)
            Text(value).font(.system(size: 12, weight: .medium, design: .rounded)).monospacedDigit()
        }
    }
}

private struct CleanupCommandCard: View {
    let command: CleanupCommand
    @State private var copied = false
    @State private var copyFailed = false
    @State private var resetTask: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(command.title).font(.system(size: 11, weight: .medium))
                Spacer()
                Link(destination: command.documentationURL) {
                    Label("官方文档", systemImage: "arrow.up.right").font(.system(size: 10))
                }.foregroundStyle(Palette.secondary)
            }
            HStack(alignment: .center, spacing: 12) {
                Text(command.command).font(.system(size: 12, design: .monospaced))
                    .textSelection(.enabled).frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                Button(action: copyCommand) {
                    Label(copied ? "已复制" : (copyFailed ? "重试复制" : "复制"), systemImage: copied ? "checkmark" : "doc.on.doc")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.accent)
                        .frame(width: 67, height: 28)
                        .background(.white, in: RoundedRectangle(cornerRadius: 6))
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Palette.line))
                }.buttonStyle(.plain).accessibilityLabel("复制命令：\(command.command)")
            }
            .padding(12).background(Palette.background, in: RoundedRectangle(cornerRadius: 8))
            Text(command.note).font(.system(size: 10)).foregroundStyle(Palette.secondary).lineSpacing(4)
            if copyFailed {
                Text("剪贴板暂不可用，也可选中上方命令手动复制。")
                    .font(.system(size: 10)).foregroundStyle(Palette.secondary)
            }
        }
        .padding(15).overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(Palette.line))
        .onDisappear { resetTask?.cancel() }
    }

    private func copyCommand() {
        resetTask?.cancel()
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        copied = pasteboard.setString(command.command, forType: .string)
        copyFailed = !copied
        resetTask = Task { @MainActor in
            do { try await Task.sleep(for: .seconds(2)) } catch { return }
            copied = false
        }
    }
}
