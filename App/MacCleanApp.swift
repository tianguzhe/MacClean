import SwiftUI

@main
struct MacCleanApp: App {
    @State private var model = ScanModel()

    var body: some Scene {
        WindowGroup {
            ContentView(model: model)
                .frame(minWidth: 1040, minHeight: 720)
                .preferredColorScheme(.light)
        }
        .windowStyle(.hiddenTitleBar)
        .defaultSize(width: 1220, height: 840)
        .commands {
            CommandGroup(after: .newItem) {
                Button("重新扫描") { model.startScan() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(model.isScanning)
                Button("停止扫描") { model.cancelScan() }
                    .keyboardShortcut(".", modifiers: .command)
                    .disabled(!model.isScanning)
            }
        }

        Settings {
            SettingsView()
                .preferredColorScheme(.light)
        }
    }
}

struct SettingsView: View {
    @AppStorage("scanOnLaunch") private var scanOnLaunch = true

    var body: some View {
        Form {
            Section("扫描") {
                Toggle("启动时自动扫描", isOn: $scanOnLaunch)
                LabeledContent("扫描范围", value: "开发缓存与编辑器资料")
                LabeledContent("统计方式", value: "文件实际分配的磁盘空间")
            }
            Section {
                Text("自定义缓存路径、项目内缓存与其他用户的目录不包含在扫描中。APFS 共享块、快照及硬链接会影响实际可释放空间。")
                    .font(.callout).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 510, height: 260)
    }
}
