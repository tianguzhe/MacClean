import SwiftUI
import MacCleanCore

struct DashboardView: View {
    let model: ScanModel
    let onBrowse: () -> Void
    let onCategory: (DeveloperCategory) -> Void
    let onSelect: (CacheDefinition) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("空间总览").font(.system(size: 28, weight: .semibold)).tracking(-0.6)
                    Text("从构建缓存到编辑器资料，了解每一份占用。")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                Spacer()
                Label(model.results.isEmpty ? "等待扫描" : "发现 \(model.presentCount) 个目录", systemImage: "folder.badge.magnifyingglass")
                    .font(.system(size: 11)).foregroundStyle(Palette.secondary)
            }
            diskOverview
            HStack(alignment: .top, spacing: 20) {
                categoryPanel.frame(maxWidth: .infinity)
                largestPanel.frame(maxWidth: .infinity)
            }.frame(height: 326)
        }
    }

    private var diskOverview: some View {
        Surface {
            VStack(alignment: .leading, spacing: 22) {
                HStack(spacing: 9) {
                    Image(systemName: "internaldrive.fill").font(.system(size: 17)).foregroundStyle(Palette.accent)
                    Text(model.disk?.name ?? "本机磁盘").font(.system(size: 14, weight: .semibold))
                    Text("内置磁盘").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                        .padding(.horizontal, 8).padding(.vertical, 4).background(Palette.background, in: Capsule())
                    Spacer()
                    Text(model.disk.map { "总容量 " + StorageFormat.string($0.totalBytes) } ?? "容量信息暂不可用")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        .help(model.diskError ?? "文件系统报告的容量")
                }
                HStack(alignment: .center, spacing: 30) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("可用空间").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        amount(model.disk?.availableBytes, size: 42, color: Palette.ink)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Rectangle().fill(Palette.line).frame(width: 1, height: 45)
                    VStack(alignment: .leading, spacing: 9) {
                        Label("开发缓存", systemImage: "shippingbox").font(.system(size: 11)).foregroundStyle(Palette.secondary)
                        amount(model.results.isEmpty ? nil : model.totalBytes, size: 27, color: Palette.accent)
                    }.frame(maxWidth: .infinity, alignment: .leading)
                    Button { onCategory(.editors) } label: {
                        VStack(alignment: .leading, spacing: 9) {
                            HStack(spacing: 6) {
                                Text("编辑器资料")
                                Image(systemName: "arrow.up.right").font(.system(size: 8))
                            }.font(.system(size: 11)).foregroundStyle(Palette.secondary)
                            amount(model.results.isEmpty ? nil : model.editorDataBytes, size: 27, color: Palette.support)
                        }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                    }.buttonStyle(.plain).help("查看代码编辑器中的配置与插件")
                }
                VStack(spacing: 13) {
                    storageBar
                    HStack(spacing: 19) {
                        legend("其他已用", color: Palette.usedSpace)
                        legend("开发缓存", color: Palette.accent)
                        legend("编辑器资料", color: Palette.support)
                        legend("可用空间", color: Palette.freeSpace)
                        Spacer()
                        Text(model.disk.map { "已使用 \(Int($0.usedFraction * 100))%" } ?? "—")
                            .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    }
                }
            }
        }
    }

    private func amount(_ bytes: Int64?, size: CGFloat, color: Color) -> some View {
        let parts = bytes.map(StorageFormat.parts)
        return HStack(alignment: .firstTextBaseline, spacing: 5) {
            Text(parts?.value ?? "—").font(.system(size: size, weight: .medium, design: .rounded)).tracking(-0.9)
            Text(parts?.unit ?? "").font(.system(size: size * 0.43, weight: .medium))
        }
        .foregroundStyle(color).monospacedDigit().contentTransition(.numericText())
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: bytes)
    }

    private var storageBar: some View {
        let total = max(1, model.disk?.totalBytes ?? 1)
        let used = model.disk?.usedBytes ?? 0
        let cache = min(model.totalBytes, used)
        let support = min(model.editorDataBytes, max(0, used - cache))
        let segments: [(Int64, Color)] = [
            (max(0, used - cache - support), Palette.usedSpace),
            (cache, Palette.accent), (support, Palette.support),
            (model.disk?.availableBytes ?? total, Palette.freeSpace)
        ].filter { $0.0 > 0 }
        return GeometryReader { proxy in
            let available = max(0, proxy.size.width - CGFloat(max(0, segments.count - 1)) * 3)
            HStack(spacing: 3) {
                ForEach(segments.indices, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 3).fill(segments[index].1)
                        .frame(width: available * CGFloat(segments[index].0) / CGFloat(total))
                }
            }
        }
        .frame(height: 15)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.5), value: model.analyzedBytes)
        .accessibilityLabel("磁盘空间分布，开发缓存 \(StorageFormat.string(model.totalBytes))，编辑器资料 \(StorageFormat.string(model.editorDataBytes))")
    }

    private func legend(_ title: String, color: Color) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 7, height: 7)
            Text(title).font(.system(size: 10)).foregroundStyle(Palette.secondary)
        }
    }

    private var categoryPanel: some View {
        Surface(padding: 20) {
            VStack(alignment: .leading, spacing: 19) {
                HStack {
                    Text("按工具分类").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Text("6 个开发生态").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    ForEach(DeveloperCategory.allCases) { category in
                        Button { onCategory(category) } label: {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack(spacing: 6) {
                                    CategoryIcon(category: category, size: 16)
                                    Text(category.title).font(.system(size: 11)).foregroundStyle(Palette.secondary)
                                    Spacer(minLength: 0)
                                }
                                HStack {
                                    Text(model.results.isEmpty ? "—" : StorageFormat.string(model.totalBytes(for: category)))
                                        .font(.system(size: 17, weight: .medium, design: .rounded)).foregroundStyle(Palette.ink).monospacedDigit()
                                    Spacer(minLength: 0)
                                    Image(systemName: "arrow.up.right").font(.system(size: 8)).foregroundStyle(Palette.secondary.opacity(0.6))
                                }
                            }
                            .padding(13).background(Palette.background, in: RoundedRectangle(cornerRadius: 10))
                            .contentShape(Rectangle())
                        }.buttonStyle(.plain)
                    }
                }
            }.frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var largestPanel: some View {
        Surface(padding: 20) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("占用较大的缓存").font(.system(size: 14, weight: .semibold))
                    Spacer()
                    Button(action: onBrowse) {
                        HStack(spacing: 4) { Text("全部"); Image(systemName: "arrow.up.right").font(.system(size: 8)) }
                            .font(.system(size: 11)).foregroundStyle(Palette.accent)
                    }.buttonStyle(.plain)
                }.padding(.bottom, 8)
                let definitions = Array(model.sortedDefinitions.filter { (model.results[$0.id]?.bytes ?? 0) > 0 }.prefix(3))
                if definitions.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "externaldrive.badge.magnifyingglass").font(.system(size: 29)).foregroundStyle(Palette.accent.opacity(0.6))
                        Text(model.isScanning ? "正在梳理开发工具目录…" : "扫描后查看缓存占用")
                            .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ForEach(Array(definitions.enumerated()), id: \.element.id) { index, definition in
                        Button { onSelect(definition) } label: {
                            HStack(spacing: 11) {
                                ToolIcon(definition: definition, size: 34)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(definition.name).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                    Text(definition.subtitle).font(.system(size: 10)).foregroundStyle(Palette.secondary).lineLimit(1)
                                }
                                Spacer(minLength: 5)
                                Text(StorageFormat.string(model.results[definition.id]?.bytes ?? 0))
                                    .font(.system(size: 13, weight: .semibold, design: .rounded)).monospacedDigit()
                            }.frame(height: 64).contentShape(Rectangle())
                        }.buttonStyle(.plain)
                        if index < definitions.count - 1 { Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 45) }
                    }
                    Spacer(minLength: 8)
                    Text("点击项目，查看目录与子项明细")
                        .font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
            }.frame(maxHeight: .infinity, alignment: .top)
        }
    }
}
