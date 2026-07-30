import SwiftUI

struct SceneDetailSheet: View {
    @EnvironmentObject private var appState: AppState

    private var scene: DreamScene { appState.currentScene }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                header
                timerSection
                SoundMixCircleEditor()
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .background(DreamTheme.deepBlue.opacity(0.55).ignoresSafeArea())
        .onAppear { appState.scheduleAutoDismissSheet() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(scene.name)
                .font(.system(size: 28, weight: .light))
                .foregroundStyle(DreamTheme.moonWhite)

            Text(scene.description)
                .font(.system(size: 14))
                .foregroundStyle(DreamTheme.secondaryText)
                .fixedSize(horizontal: false, vertical: true)

            Label("\(scene.mockListenerCount) 人正在收听", systemImage: "headphones")
                .font(.system(size: 12))
                .foregroundStyle(DreamTheme.tertiaryText)
                // Demo data — not live online count.

            HStack(spacing: 12) {
                sheetAction(
                    title: scene.isFavorite ? "已收藏" : "收藏",
                    symbol: scene.isFavorite ? "heart.fill" : "heart"
                ) {
                    appState.toggleFavorite(sceneId: scene.id)
                }

                sheetAction(title: "锁屏说明", symbol: "lock.iphone") {
                    appState.lockScreenPlayEnabled = true
                    appState.persistSettings()
                    appState.markSheetInteraction()
                }
            }
        }
    }

    private var timerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("定时停止")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(DreamTheme.moonWhite)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TimerOption.allCases) { option in
                        TimerOptionChip(
                            option: option,
                            selected: appState.timerOption == option,
                            progress: appState.timerOption == option ? appState.timerElapsedProgress : 0
                        ) {
                            appState.setTimerOption(option)
                            appState.markSheetInteraction()
                        }
                    }
                }
            }
        }
    }

    private func sheetAction(title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 11))
            }
            .foregroundStyle(DreamTheme.moonWhite.opacity(0.85))
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.08)))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
    }
}

#Preview {
    SceneDetailSheet()
        .environmentObject(AppState())
}
