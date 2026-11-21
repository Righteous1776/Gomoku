import SwiftUI

struct GomokuCoachView: View {
    @ObservedObject var engine: NativeGomokuAppController

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("ECLIPSE · PERSONAL COACH")
                        .font(.caption.monospaced().weight(.semibold))
                        .foregroundStyle(.secondary)
                    if engine.isCoachLoading {
                        ProgressView("正在复核本地历史与训练数据…")
                    } else if let profile = engine.coachProfile {
                        Text("学习等级 Lv\(profile.level)")
                            .font(.title2.weight(.semibold))
                        VStack(alignment: .leading, spacing: 8) {
                            metric("已完成真实个人对局", profile.completedHumanGames)
                            metric("有效唯一原生自对弈", profile.verifiedSelfPlayGames)
                            metric("已验证的原版历史棋局", profile.verifiedLegacyGames)
                            metric("已记忆的真实局面", profile.rememberedPositions)
                            metric("已签名的开发者阵法", profile.developerFormations)
                            metric("重复失利线路", profile.repeatedLosingLines)
                        }
                        Divider()
                        Text(profile.favoriteOpening)
                            .font(.subheadline.weight(.semibold))
                        Text(profile.reviewFocus)
                        Text(profile.nextLesson)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("尚未生成已验证的学习统计。")
                            .foregroundStyle(.secondary)
                    }
                    Button("重新检验统计") { engine.refreshCoachProfile() }
                        .buttonStyle(.bordered)
                }
                .padding(20)
            }
            .navigationTitle("个人教练")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { engine.refreshCoachProfile() }
        }
    }

    private func metric(_ label: String, _ value: Int) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            Text(value.formatted()).monospacedDigit().fontWeight(.semibold)
        }
        .font(.subheadline)
    }
}
