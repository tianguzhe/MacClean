import SwiftUI
import MacCleanCore

enum CacheSort: String, CaseIterable {
    case size = "占用空间", name = "名称"
}

private enum EditorFilter: String, CaseIterable {
    case all = "全部", cache = "缓存", support = "配置与插件"

    func includes(_ definition: CacheDefinition) -> Bool {
        switch self {
        case .all: true
        case .cache: definition.kind == .cache
        case .support: definition.kind == .applicationSupport
        }
    }
}

struct CacheLibraryView: View {
    let model: ScanModel
    let category: DeveloperCategory?
    let onSelect: (CacheDefinition) -> Void
    @State private var search = ""
    @State private var sort = CacheSort.size
    @State private var showMissing = false
    @State private var filter = EditorFilter.all

    private var isEditors: Bool { category == .editors }
    private var title: String { category?.title ?? "开发缓存" }

    private var scopedDefinitions: [CacheDefinition] {
        model.definitions.filter {
            (category == nil || $0.category == category) && (isEditors || $0.kind == .cache)
        }
    }

    private var discoveryIssues: [ScanIssue] {
        return model.discoveryIssues.filter {
            if let category { return $0.category == category }
            return $0.kind != .applicationSupport
        }
    }

    private var visible: [CacheDefinition] {
        scopedDefinitions.filter { definition in
            (!isEditors || filter.includes(definition)) &&
            (search.isEmpty || (definition.name + definition.subtitle + definition.paths.joined()).localizedCaseInsensitiveContains(search)) &&
            (showMissing || model.results[definition.id]?.isPresent != false)
        }.sorted {
            let left = model.results[$0.id]?.bytes ?? 0
            let right = model.results[$1.id]?.bytes ?? 0
            if sort == .size && left != right { return left > right }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }
    }

    private var visibleBytes: Int64 { visible.reduce(0) { $0 + (model.results[$1.id]?.bytes ?? 0) } }
    private var issueCount: Int { visible.filter { model.results[$0.id]?.issues.isEmpty == false }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 23) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(title).font(.system(size: 28, weight: .semibold)).tracking(-0.6)
                    Text(isEditors ? "编辑器缓存、配置与插件，集中在这里。" : "按占用查看开发工具缓存，定位具体目录。")
                        .font(.system(size: 12)).foregroundStyle(Palette.secondary)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 5) {
                    Text(model.results.isEmpty ? "—" : StorageFormat.string(visibleBytes))
                        .font(.system(size: 27, weight: .medium, design: .rounded)).monospacedDigit()
                    Text("当前列表 · \(visible.count) 个项目").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
            }

            VStack(spacing: 0) {
                listToolbar.padding(16)
                Rectangle().fill(Palette.line).frame(height: 1)
                HStack {
                    Text("工具与目录")
                    Spacer()
                    if isEditors { Text("数据类型").frame(width: 100, alignment: .center) }
                    Text("磁盘占用").frame(width: 105, alignment: .trailing)
                    Color.clear.frame(width: 22, height: 1)
                }
                .font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary)
                .padding(.horizontal, 20).frame(height: 37).background(Palette.background.opacity(0.65))
                Rectangle().fill(Palette.line).frame(height: 1)
                LazyVStack(spacing: 0) {
                    if visible.isEmpty {
                        ContentUnavailableView(search.isEmpty ? "没有发现相关目录" : "没有匹配的项目", systemImage: search.isEmpty ? "folder.badge.questionmark" : "magnifyingglass", description: Text(search.isEmpty ? "可以调整类型筛选，或在显示选项中查看未发现的目录。" : "试试工具名称、版本号或目录路径。"))
                            .frame(minHeight: 260)
                    } else {
                        ForEach(Array(visible.enumerated()), id: \.element.id) { index, definition in
                            CacheRow(definition: definition, result: model.results[definition.id], maxBytes: visibleBytes, isScanning: model.isScanning, showsKind: isEditors) { onSelect(definition) }
                            if index < visible.count - 1 { Rectangle().fill(Palette.line).frame(height: 1).padding(.leading, 71) }
                        }
                    }
                }
            }
            .background(.white, in: RoundedRectangle(cornerRadius: 14))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Palette.line))

            HStack(alignment: .top, spacing: 7) {
                Image(systemName: "info.circle")
                Text(isEditors ? "配置与插件包含各版本的个人设置和历史数据，按编辑器资料统计。点击项目可查看子项。" : "统计默认目录的实际磁盘占用。项目内与自定义位置的缓存不包含在内。")
                    .lineSpacing(3)
                Spacer(minLength: 0)
                if issueCount > 0 {
                    Label("\(issueCount) 项部分读取", systemImage: "exclamationmark.circle")
                        .foregroundStyle(Color(hex: 0xB38A53))
                }
            }.font(.system(size: 10)).foregroundStyle(Palette.secondary)

            ForEach(discoveryIssues) { issue in
                DisclosureGroup {
                    Text(StorageFormat.path(URL(fileURLWithPath: issue.path)) + "\n" + issue.message)
                        .foregroundStyle(Palette.secondary).textSelection(.enabled).padding(.top, 8)
                } label: {
                    Label("有目录未能完成检测", systemImage: "exclamationmark.circle").foregroundStyle(Color(hex: 0xB38A53))
                }.font(.system(size: 11)).padding(15).background(.white, in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var listToolbar: some View {
        HStack(spacing: 12) {
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                TextField(isEditors ? "搜索编辑器、版本或路径" : "搜索工具或路径", text: $search)
                    .textFieldStyle(.plain).font(.system(size: 12))
                if !search.isEmpty {
                    Button { search = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Palette.secondary.opacity(0.6)) }
                        .buttonStyle(.plain).help("清除搜索")
                }
            }
            .padding(.horizontal, 10).frame(minWidth: 170, maxWidth: 260).frame(height: 32)
            .background(Palette.background, in: RoundedRectangle(cornerRadius: 7))
            Spacer(minLength: 0)
            if isEditors {
                Picker("数据类型", selection: $filter) {
                    ForEach(EditorFilter.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }.pickerStyle(.segmented).labelsHidden().frame(width: 222).controlSize(.small)
            }
            Picker("排序", selection: $sort) {
                ForEach(CacheSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
            }.labelsHidden().frame(width: 104).controlSize(.small)
            Menu {
                Toggle("显示未发现的目录", isOn: $showMissing)
            } label: {
                Image(systemName: "ellipsis").font(.system(size: 15)).foregroundStyle(Palette.secondary)
                    .frame(width: 25, height: 29)
            }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("显示选项")
        }
    }
}

struct CacheRow: View {
    let definition: CacheDefinition
    let result: CacheScanResult?
    let maxBytes: Int64
    let isScanning: Bool
    var showsKind = true
    let action: () -> Void
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            HStack(spacing: 13) {
                ToolIcon(definition: definition)
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text(definition.name).font(.system(size: 13, weight: .medium)).lineLimit(1).truncationMode(.middle)
                        if let result, !result.issues.isEmpty {
                            Image(systemName: "exclamationmark.circle").font(.system(size: 10)).foregroundStyle(Color(hex: 0xB38A53))
                        }
                    }
                    Text(definition.subtitle).font(.system(size: 10)).foregroundStyle(Palette.secondary).lineLimit(1)
                }
                Spacer(minLength: 8)
                if showsKind { KindBadge(kind: definition.kind).frame(width: 100) }
                VStack(alignment: .trailing, spacing: 8) {
                    Text(sizeText).font(.system(size: 14, weight: .medium, design: .rounded)).monospacedDigit()
                        .foregroundStyle(result?.isPresent == false ? Palette.secondary : Palette.ink)
                    GeometryReader { proxy in
                        Capsule().fill(Palette.line)
                            .overlay(alignment: .leading) {
                                if let result, result.bytes > 0 {
                                    Capsule().fill(definition.kind == .cache ? Palette.category(definition.category) : Palette.support)
                                        .frame(width: max(3, proxy.size.width * min(1, Double(result.bytes) / Double(max(1, maxBytes)))))
                                }
                            }
                    }.frame(width: 70, height: 3)
                }.frame(width: 105, alignment: .trailing)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .medium)).foregroundStyle(Palette.secondary.opacity(0.5)).frame(width: 9)
            }
            .padding(.horizontal, 20).frame(height: 74)
            .background(isHovered ? Palette.background : .clear).contentShape(Rectangle())
        }
        .buttonStyle(.plain).onHover { isHovered = $0 }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: isHovered)
        .accessibilityLabel("\(definition.name)，\(definition.kind == .cache ? "缓存" : "配置与插件")，\(sizeText)，查看详情")
    }

    private var sizeText: String {
        guard let result else { return isScanning ? "等待扫描" : "尚未扫描" }
        if !result.isPresent { return "未发现" }
        if !result.issues.isEmpty && result.bytes == 0 { return "无法读取" }
        return StorageFormat.string(result.bytes)
    }
}
