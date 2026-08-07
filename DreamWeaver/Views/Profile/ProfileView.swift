import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.sceneAdaptiveAccent) private var sceneAccent

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    profileHeader
                    AppleSignInSection()
                    companionshipSection
                    settingsEntry
                }
                .padding(20)
                .padding(.bottom, 120)
            }
            .background(Color.clear)
            .navigationBarHidden(true)
        }
        .background(Color.clear)
    }

    private var profileHeader: some View {
        HStack(spacing: 16) {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            sceneAccent.opacity(0.86),
                            appState.currentScene.palette.midColor.opacity(0.78)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 68, height: 68)
                .overlay {
                    Text(String(appState.nickname.prefix(1)))
                        .font(DreamTypography.pageTitle)
                        .foregroundStyle(DreamTheme.moonWhite)
                }
                .accessibilityLabel("头像")

            VStack(alignment: .leading, spacing: 6) {
                Text(appState.nickname)
                    .font(DreamTypography.pageTitle)
                    .foregroundStyle(DreamTheme.moonWhite)
                Text(appState.isMember ? "织梦会员" : "免费体验")
                    .font(DreamTypography.caption.weight(.medium))
                    .foregroundStyle(sceneAccent)
            }
            Spacer()
        }
        .padding(.top, 12)
    }

    private var companionshipSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("陪伴记录")
                .font(DreamTypography.sectionTitle)
                .foregroundStyle(DreamTheme.moonWhite)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                statCard("累计使用时长", appState.usageRecord.totalHoursText)
                statCard("本周使用时长", appState.usageRecord.weekHoursText)
                statCard("常用入睡时间", appState.usageRecord.usualBedtime)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text("睡眠趋势")
                    .font(DreamTypography.cardTitle)
                    .foregroundStyle(DreamTheme.moonWhite)

                GeometryReader { geo in
                    let values = appState.usageRecord.sleepTrend
                    let maxV = CGFloat(values.max() ?? 1)
                    HStack(alignment: .bottom, spacing: 8) {
                        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                            VStack(spacing: 6) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(sceneAccent.opacity(0.55))
                                    .frame(
                                        width: (geo.size.width - 48) / 7,
                                        height: max(8, CGFloat(value) / maxV * 70)
                                    )
                                Text(["一", "二", "三", "四", "五", "六", "日"][index])
                                    .font(.system(size: 10))
                                    .foregroundStyle(DreamTheme.tertiaryText)
                            }
                        }
                    }
                }
                .frame(height: 100)
                .padding(14)
                .dreamGlass(cornerRadius: 16)
                .accessibilityLabel("睡眠趋势图")
            }
        }
    }

    private var settingsEntry: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("设置")
                .font(DreamTypography.sectionTitle)
                .foregroundStyle(DreamTheme.moonWhite)

            NavigationLink {
                SettingsView()
                    .environmentObject(appState)
            } label: {
                row("全部设置", "gearshape")
            }
        }
    }

    private func statCard(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(DreamTypography.caption)
                .foregroundStyle(DreamTheme.secondaryText)
            Text(value)
                .font(DreamTypography.cardTitle)
                .foregroundStyle(DreamTheme.moonWhite)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.06)))
    }

    private func row(_ title: String, _ symbol: String) -> some View {
        HStack {
            Image(systemName: symbol)
                .font(.system(size: DreamIconSize.secondary, weight: .medium))
                .foregroundStyle(sceneAccent)
                .frame(width: 28)
            Text(title)
                .foregroundStyle(DreamTheme.moonWhite)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: DreamIconSize.content, weight: .semibold))
                .foregroundStyle(DreamTheme.tertiaryText)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Color.white.opacity(0.05)))
    }
}

#Preview {
    ProfileView()
        .environmentObject(AppState())
}
