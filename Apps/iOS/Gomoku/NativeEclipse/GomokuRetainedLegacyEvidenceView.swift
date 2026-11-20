import SwiftUI

/// Developer-gated, read-only access to unchanged legacy source envelopes.
/// Sharing is explicit: nothing is exported, deleted or trained automatically.
struct GomokuRetainedLegacyEvidenceView: View {
    @ObservedObject var engine: NativeGomokuAppController
    @ObservedObject var authorization: GomokuDeveloperAuthorization
    @State private var sources: [GomokuRetainedLegacyEvidence.Source] = []
    @State private var verificationError: String?

    var body: some View {
        DisclosureGroup("原始数据审计与导出") {
            VStack(alignment: .leading, spacing: 9) {
                Text("仅供设备持有人检查。这里保留完整原始文件（含未完成棋谱和哈希统计）；这些内容不会因为查看或导出而转为 AI 学习权重。")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let verificationError {
                    Label(verificationError, systemImage: "exclamationmark.shield")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else if sources.isEmpty {
                    Text("本机暂无已导入的原始训练存档。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(sources) { source in
                        VStack(alignment: .leading, spacing: 4) {
                            Text("SHA256 · " + String(source.id.prefix(12)) + "…")
                                .font(.caption.monospaced())
                            Text("原始记录 \(source.originalGameRecords) 条 · 哈希局面 \(source.hashedPositionEntries) 项 · \(source.byteCount) B")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            ShareLink(item: source.url) {
                                Label("主动导出此份私人原始档案", systemImage: "square.and.arrow.up")
                                    .font(.caption)
                            }
                            .disabled(!authorization.isAuthorized || engine.isImportingLegacyLearning)
                            .accessibilityIdentifier("gomoku.owner.raw-export." + source.id)
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .padding(.top, 8)
        }
        .task(id: engine.isImportingLegacyLearning) {
            guard authorization.isAuthorized, !engine.isImportingLegacyLearning else {
                sources = []
                return
            }
            let directory = GomokuLegacyLearningImporter().directory
            do {
                let originals = try await Task.detached(priority: .utility) {
                    try GomokuRetainedLegacyEvidence.list(directory: directory)
                }.value
                guard authorization.isAuthorized else { sources = []; return }
                sources = originals
                verificationError = nil
            } catch {
                sources = []
                verificationError = error.localizedDescription
            }
        }
        .onChange(of: authorization.isAuthorized) { _, valid in
            if !valid { sources = [] }
        }
    }
}
