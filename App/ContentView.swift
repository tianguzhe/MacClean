import SwiftUI
import MacCleanCore

enum Destination: Hashable {
    case overview, caches, category(DeveloperCategory)

    var title: String {
        switch self {
        case .overview: "空间总览"
        case .caches: "开发缓存"
        case .category(let category): category.title
        }
    }
}

struct ContentView: View {
    let model: ScanModel
    @State private var destination = Destination.overview
    @State private var detail: CacheDefinition?
    @AppStorage("scanOnLaunch") private var scanOnLaunch = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Rectangle().fill(Palette.line).frame(width: 1)
            VStack(spacing: 0) {
                toolbar
                ScrollView {
                    Group {
                        if destination == .overview {
                            DashboardView(model: model, onBrowse: { destination = .caches }, onCategory: { destination = .category($0) }, onSelect: { detail = $0 })
                        } else {
                            CacheLibraryView(model: model, category: selectedCategory, onSelect: { detail = $0 })
                        }
                    }
                    .id(destination)
                    .transition(.opacity)
                    .padding(30)
                    .frame(maxWidth: 1240)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                footer
            }
            .background(Palette.background)
        }
        .foregroundStyle(Palette.ink)
        .sheet(item: $detail) { definition in
            CacheDetailView(definition: definition, result: model.results[definition.id], isScanning: model.isScanning)
        }
        .task { if scanOnLaunch && !model.hasScanned && !model.isScanning { model.startScan() } }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: destination)
        .tint(Palette.accent)
    }

    private var selectedCategory: DeveloperCategory? {
        if case .category(let category) = destination { return category }
        return nil
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Image("MacCleanMark").resizable().scaledToFit().frame(width: 38, height: 38)
                VStack(alignment: .leading, spacing: 3) {
                    Text("MacClean").font(.system(size: 18, weight: .semibold, design: .rounded)).tracking(-0.4)
                    Text("给开发，留点空间").font(.system(size: 10)).foregroundStyle(Palette.secondary)
                }
            }.padding(.horizontal, 23).padding(.top, 30).padding(.bottom, 32)

            navItem("空间总览", symbol: "square.grid.2x2", destination: .overview)
            navItem("开发缓存", symbol: "internaldrive", destination: .caches)

            Text("开发工具").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.secondary)
                .padding(.leading, 26).padding(.top, 30).padding(.bottom, 12)
            ForEach(DeveloperCategory.allCases) { category in
                navItem(category.title, symbol: category.symbol, destination: .category(category))
            }
            Spacer(minLength: 25)
            sidebarDisk
            Rectangle().fill(Palette.line).frame(height: 1).padding(.horizontal, 22).padding(.vertical, 18)
            HStack {
                SettingsLink {
                    Label("偏好设置", systemImage: "slider.horizontal.3")
                        .font(.system(size: 11)).foregroundStyle(Palette.secondary)
                }.buttonStyle(.plain)
                Spacer()
                Text(Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(Palette.secondary.opacity(0.6))
            }.padding(.horizontal, 25).padding(.bottom, 22)
        }
        .frame(width: 216)
        .background(Palette.sidebar.gradient)
    }

    private func navItem(_ title: String, symbol: String, destination item: Destination) -> some View {
        let selected = destination == item
        return Button { destination = item } label: {
            HStack(spacing: 10) {
                if case .category(let category) = item {
                    CategoryIcon(category: category, size: 20).frame(width: 20)
                } else {
                    Image(systemName: symbol).font(.system(size: 14, weight: selected ? .semibold : .regular)).frame(width: 20)
                }
                Text(title).font(.system(size: 12, weight: selected ? .semibold : .regular)).lineLimit(1)
                Spacer(minLength: 4)
                if case .category(let category) = item, model.totalBytes(for: category) > 0 {
                    Text(StorageFormat.string(model.totalBytes(for: category)))
                        .font(.system(size: 9, weight: .medium, design: .rounded)).monospacedDigit()
                        .foregroundStyle(selected ? Palette.accent : Palette.secondary)
                }
            }
            .foregroundStyle(selected ? Palette.accent : Palette.ink.opacity(0.7))
            .padding(.horizontal, 11).frame(height: 39)
            .background(selected ? .white : .clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Palette.line : .clear))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain).padding(.horizontal, 14).padding(.bottom, 5)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var sidebarDisk: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "internaldrive").font(.system(size: 15)).foregroundStyle(Palette.accent)
                Text(model.disk?.name ?? "本机磁盘").font(.system(size: 11, weight: .medium))
            }
            GeometryReader { proxy in
                Capsule().fill(Palette.accent.opacity(0.1))
                    .overlay(alignment: .leading) {
                        Capsule().fill(Palette.accent.opacity(0.55)).frame(width: proxy.size.width * (model.disk?.usedFraction ?? 0))
                    }
            }.frame(height: 4)
            Text(model.disk.map { "可用 " + StorageFormat.string($0.availableBytes) } ?? "磁盘信息暂不可用")
                .font(.system(size: 10)).foregroundStyle(Palette.secondary).monospacedDigit()
        }.padding(.horizontal, 26)
    }

    private var toolbar: some View {
        VStack(spacing: 0) {
            HStack(spacing: 9) {
                Image(systemName: "internaldrive").font(.system(size: 12)).foregroundStyle(Palette.secondary)
                Text(model.disk?.name ?? "本机磁盘").foregroundStyle(Palette.secondary)
                Image(systemName: "chevron.right").font(.system(size: 8)).foregroundStyle(Palette.secondary.opacity(0.5))
                Text(destination.title).fontWeight(.medium)
                Spacer()
                if model.isScanning {
                    ProgressView().controlSize(.mini).scaleEffect(0.8).frame(width: 14)
                } else {
                    Circle().fill(Palette.accent.opacity(0.7)).frame(width: 5, height: 5)
                }
                Text(model.statusText).font(.system(size: 10)).foregroundStyle(Palette.secondary)
                    .padding(.trailing, 12)
                ScanButton(model: model)
            }
            .font(.system(size: 11))
            .padding(.horizontal, 30).frame(height: 57)
            GeometryReader { proxy in
                Rectangle().fill(Palette.line)
                    .overlay(alignment: .leading) {
                        if model.isScanning {
                            Rectangle().fill(Palette.accent.opacity(0.6)).frame(width: proxy.size.width * model.progress)
                        }
                    }
            }.frame(height: 1)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: model.progress)
        }.background(.white.opacity(0.7))
    }

    private var footer: some View {
        HStack(spacing: 6) {
            Image(systemName: "lock.shield").font(.system(size: 10))
            Text("只读分析 · 数据留在本机")
            Spacer()
            if !model.results.isEmpty { Text("已分析 \(model.fileCount.formatted()) 个文件").monospacedDigit() }
        }
        .font(.system(size: 10)).foregroundStyle(Palette.secondary)
        .padding(.horizontal, 30).frame(height: 32)
    }
}
