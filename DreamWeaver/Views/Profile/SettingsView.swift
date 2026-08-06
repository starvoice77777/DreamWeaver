import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @State private var apiBaseURLDraft = ServiceBackendConfig.apiBaseURLString.isEmpty
        ? ServiceBackendConfig.remoteBaseURL.absoluteString
        : ServiceBackendConfig.apiBaseURLString

    var body: some View {
        List {
            Section("演示控制") {
                Toggle("显示演示加速定时", isOn: $appState.showDemoControls)
                VStack(alignment: .leading, spacing: 10) {
                    Text("内容数据源")
                        .foregroundStyle(DreamTheme.moonWhite)
                    Picker("内容数据源", selection: $appState.preferredContentBackend) {
                        ForEach(ServiceBackendMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .accessibilityLabel("内容数据源")
                }
                .listRowBackground(Color.white.opacity(0.05))
                VStack(alignment: .leading, spacing: 8) {
                    Text("远程 API 基址（dw.apiBaseURL）")
                        .foregroundStyle(DreamTheme.moonWhite)
                    TextField("http://192.168.x.x:8000", text: $apiBaseURLDraft)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .foregroundStyle(DreamTheme.moonWhite)
                    Button("保存基址") {
                        applyAPIBaseURL()
                    }
                    .foregroundStyle(DreamTheme.warmApricot)
                }
                .listRowBackground(Color.white.opacity(0.05))
                if appState.contentBackendMode == .remote {
                    if appState.isRemoteAuthenticated {
                        Button("退出远程登录") {
                            Task { await appState.signOutRemote() }
                        }
                        .foregroundStyle(DreamTheme.warmApricot)
                        Button("云端保存当前混音") {
                            Task { await appState.saveCurrentMixToRemote() }
                        }
                        .foregroundStyle(DreamTheme.warmApricot)
                    } else {
                        Button("开发登录（dev:demo-user）") {
                            Task { await appState.signInWithDevAccount() }
                        }
                        .foregroundStyle(DreamTheme.warmApricot)
                    }
                }
                Button("重置为标准演示状态") {
                    appState.resetDemoState()
                }
                .foregroundStyle(DreamTheme.warmApricot)
                if let message = appState.lastServiceMessage {
                    Text(message)
                        .font(DreamTypography.caption)
                        .foregroundStyle(DreamTheme.secondaryText)
                }
            }

            Section("播放") {
                Toggle("自动播放", isOn: $appState.autoPlayEnabled)
                Toggle("后台播放", isOn: $appState.backgroundPlayEnabled)
                Toggle("锁屏播放", isOn: $appState.lockScreenPlayEnabled)
                Picker("音频质量", selection: $appState.audioQuality) {
                    Text("标准").tag("标准")
                    Text("高品质").tag("高品质")
                    Text("节省流量").tag("节省流量")
                }
            }

            Section("通知与存储") {
                Toggle("通知设置", isOn: $appState.notificationsEnabled)
                NavigationLink("下载与存储") {
                    SettingsDetailPage(
                        title: "下载与存储",
                        bodyText: "演示模式下声音与场景均保存在本地内存，不会占用额外下载空间。"
                    )
                }
            }

            Section("显示与动画") {
                Toggle("深色模式", isOn: $appState.darkModeForced)
                HStack {
                    Text("动画强度")
                    Slider(value: $appState.animationIntensity, in: 0.2...1)
                        .tint(DreamTheme.mistBlue)
                        .accessibilityLabel("动画强度")
                }
                Toggle("减少动态效果", isOn: $appState.reduceMotion)
            }

            Section("辅助功能") {
                NavigationLink("辅助功能") {
                    SettingsDetailPage(
                        title: "辅助功能",
                        bodyText: "支持动态字体、较大点击区域，以及减少动态效果。重要状态不只依赖颜色表达。"
                    )
                }
            }

            Section("隐私与权限") {
                NavigationLink("隐私与权限") {
                    SettingsDetailPage(
                        title: "隐私与权限",
                        bodyText: "织梦重视你的隐私。演示版不会上传录音，也不会连接服务器。"
                    )
                }
                NavigationLink("麦克风权限") {
                    SettingsDetailPage(
                        title: "麦克风权限",
                        bodyText: "演示录制不会真正请求麦克风。正式版本会在录制前说明用途。"
                    )
                }
                NavigationLink("本地文件权限") {
                    SettingsDetailPage(
                        title: "本地文件权限",
                        bodyText: "演示上传不会读取真实文件。正式版本仅在你选择时访问本地录音。"
                    )
                }
            }

            Section("关于") {
                NavigationLink("用户协议") {
                    SettingsDetailPage(title: "用户协议", bodyText: "这是演示用的用户协议摘要。使用织梦即表示你理解本应用当前为前端演示版本。")
                }
                NavigationLink("隐私政策") {
                    SettingsDetailPage(title: "隐私政策", bodyText: "演示版不会收集个人数据，也不会进行云端同步。")
                }
                NavigationLink("意见反馈") {
                    SettingsDetailPage(title: "意见反馈", bodyText: "如有想法，可以在比赛演示后告诉我们。感谢你的陪伴。")
                }
                NavigationLink("关于织梦") {
                    SettingsDetailPage(
                        title: "关于织梦",
                        bodyText: "织梦是一款以场景为核心的沉浸式助眠应用。通过动态场景、氛围动画、空间声音和熟悉的陪伴声音，提供温和克制的睡前体验。\n\n版本 0.1 Demo"
                    )
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(DreamTheme.deepBlue.ignoresSafeArea())
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
        .tint(DreamTheme.mistBlue)
        .onChange(of: appState.autoPlayEnabled) { _, _ in appState.persistSettings() }
        .onChange(of: appState.backgroundPlayEnabled) { _, _ in appState.persistSettings() }
        .onChange(of: appState.lockScreenPlayEnabled) { _, _ in appState.persistSettings() }
        .onChange(of: appState.reduceMotion) { _, _ in appState.persistSettings() }
        .onChange(of: appState.darkModeForced) { _, _ in appState.persistSettings() }
        .onChange(of: appState.animationIntensity) { _, _ in appState.persistSettings() }
        .onChange(of: appState.audioQuality) { _, _ in appState.persistSettings() }
        .onChange(of: appState.notificationsEnabled) { _, _ in appState.persistSettings() }
        .onChange(of: appState.preferredContentBackend) { _, mode in
            ServiceBackendConfig.mode = mode
            if mode != appState.contentBackendMode {
                appState.lastServiceMessage = "已切换到\(mode.title)，请完全退出 App 后重开生效"
            }
        }
    }

    private func applyAPIBaseURL() {
        let trimmed = apiBaseURLDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty, url.scheme != nil, url.host != nil else {
            appState.lastServiceMessage = "基址无效，请使用类似 http://192.168.120.62:8000"
            return
        }
        ServiceBackendConfig.apiBaseURLString = trimmed
        apiBaseURLDraft = trimmed
        Task {
            await APIClient.shared.setBaseURL(url)
        }
        appState.lastServiceMessage = "已保存远程基址 \(trimmed)。若刚切换远程模式，请完全退出 App 后重开。"
    }
}

struct SettingsDetailPage: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let bodyText: String

    var body: some View {
        ZStack {
            DreamTheme.deepBlue
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { dismiss() }

            ScrollView {
                Text(bodyText)
                    .font(.system(size: 15))
                    .foregroundStyle(DreamTheme.secondaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack {
        SettingsView()
            .environmentObject(AppState())
    }
}
