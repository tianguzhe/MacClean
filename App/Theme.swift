import SwiftUI
import MacCleanCore

enum Palette {
    static let background = Color(hex: 0xF7F8FC)
    static let ink = Color(hex: 0x29314A)
    static let secondary = Color(hex: 0x646D82)
    static let accent = Color(hex: 0x5963C5)
    static let line = Color(hex: 0xE5E8F1)
    static let sidebar = Color(hex: 0xEEF0F8)
    static let support = Color(hex: 0x7D609F)
    static let usedSpace = Color(hex: 0xBEC5DB)
    static let freeSpace = Color(hex: 0xE9ECF5)

    static func category(_ category: DeveloperCategory) -> Color {
        switch category {
        case .apple: Color(hex: 0x4C87AD)
        case .javascript: Color(hex: 0xA47A32)
        case .android: Color(hex: 0x6979B1)
        case .python: Color(hex: 0x9473AB)
        case .packages: Color(hex: 0xAE7762)
        case .editors: Color(hex: 0x6673C0)
        }
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(.sRGB, red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255, blue: Double(hex & 0xFF) / 255, opacity: 1)
    }
}

enum StorageFormat {
    static func string(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: max(0, bytes), countStyle: .decimal)
    }

    static func parts(_ bytes: Int64) -> (value: String, unit: String) {
        let components = string(bytes).split(separator: " ")
        guard components.count > 1 else { return (string(bytes), "") }
        return (components.dropLast().joined(separator: " "), String(components.last!))
    }

    static func path(_ url: URL) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        return url.path.hasPrefix(home + "/") ? "~" + url.path.dropFirst(home.count) : url.path
    }
}

struct Surface<Content: View>: View {
    var padding: CGFloat = 24
    @ViewBuilder var content: Content

    var body: some View {
        content.padding(padding)
            .background(.white, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(Palette.line, lineWidth: 1))
    }
}

struct ToolIcon: View {
    let definition: CacheDefinition
    var size: CGFloat = 38

    var body: some View {
        Group {
            if let asset = brandAsset {
                Image("Brand-" + asset).resizable().renderingMode(.original).scaledToFit()
                    .frame(width: (size * 0.35).rounded() * 2, height: (size * 0.35).rounded() * 2)
            } else {
                Image(systemName: definition.symbol)
                    .font(.system(size: size * 0.41, weight: .medium))
                    .foregroundStyle(Palette.category(definition.category))
            }
        }
            .frame(width: size, height: size)
            .background(Palette.background, in: RoundedRectangle(cornerRadius: size * 0.27))
            .accessibilityHidden(true)
    }

    private var brandAsset: String? {
        if definition.id.hasPrefix("android-studio-") { return "androidstudio" }
        return [
            "xcode-derived": "xcode", "xcode-cache": "xcode", "swiftpm": "swift",
            "npm": "npm", "npm-exec": "npm", "pnpm": "pnpm", "yarn": "yarn", "bun": "bun",
            "node-gyp": "nodejs", "nvm": "nodejs", "deno": "denojs", "cypress": "cypressio",
            "puppeteer": "puppeteer", "gradle": "gradle", "gradle-wrapper": "gradle",
            "android": "android", "maven": "maven", "coursier": "scala", "ivy": "scala",
            "pip": "pypi", "uv": "uv", "poetry": "poetry", "conda": "anaconda",
            "huggingface": "huggingface", "homebrew": "homebrew", "cargo": "rust",
            "go": "go", "go-modules": "go", "composer": "composer", "nuget": "nuget",
            "nuget-http": "nuget", "nuget-plugins": "nuget", "dart-pub": "dart",
            "vscode": "vscode", "cursor": "cursor", "jetbrains": "jetbrains", "helm": "helm"
        ][definition.id]
    }
}

struct CategoryIcon: View {
    let category: DeveloperCategory
    var size: CGFloat = 16

    private var asset: String? {
        switch category {
        case .apple: "swift"
        case .javascript: "javascript"
        case .android: "java"
        case .python: "python"
        case .packages, .editors: nil
        }
    }

    var body: some View {
        Group {
            if let asset {
                Image("Brand-" + asset).resizable().renderingMode(.original).scaledToFit()
            } else {
                Image(systemName: category.symbol).font(.system(size: size * 0.86))
                    .foregroundStyle(Palette.category(category))
            }
        }.frame(width: size, height: size).accessibilityHidden(true)
    }
}

struct KindBadge: View {
    let kind: StorageKind

    var body: some View {
        Text(kind == .cache ? "缓存" : "配置与插件")
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(kind == .cache ? Palette.accent : Palette.support)
            .padding(.horizontal, 8).padding(.vertical, 4)
            .background((kind == .cache ? Palette.accent : Palette.support).opacity(0.075), in: Capsule())
    }
}

struct ScanButton: View {
    let model: ScanModel

    var body: some View {
        Button {
            if model.isScanning { model.cancelScan() } else { model.startScan() }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: model.isScanning ? "stop.fill" : "arrow.clockwise")
                    .font(.system(size: 11, weight: .semibold))
                Text(model.isScanning ? (model.isCancelling ? "正在停止" : "停止扫描") : (model.hasScanned ? "重新扫描" : "开始扫描"))
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 15).frame(height: 33)
            .background(Palette.accent, in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain).disabled(model.isCancelling)
        .help(model.isScanning ? "停止扫描（⌘.）" : "扫描开发工具目录（⌘R）")
    }
}
