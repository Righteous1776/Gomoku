import SwiftUI
import UniformTypeIdentifiers

/// Private, device-owner-authorized ECLIPSE formation lab. Teaching never
/// enters the ordinary match journal and never silently imports other apps.
struct GomokuDeveloperLearningLabView: View {
    @ObservedObject var engine: NativeGomokuAppController
    @ObservedObject var authorization: GomokuDeveloperAuthorization

    @State private var choosingPackage = false
    @State private var name = ""
    @State private var purpose = ""
    @State private var objective = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("私有阵法教学 · ECLIPSE")
                        .font(.title3.weight(.semibold))
                    Text("此区域仅在通过设备持有人验证后开放。可在棋盘上手动演示黑白双方攻防，并将经过校验的完整路线保存为本机签名阵法。")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if authorization.isAuthorized {
                        Label("本次设备身份验证有效", systemImage: "checkmark.shield")
                            .foregroundStyle(.green)
                        HStack {
                            Button(engine.developerTeachingMode ? "重新开始示范" : "开始黑白棋教学") {
                                engine.beginDeveloperTeaching()
                            }
                            .buttonStyle(.borderedProminent)
                            if engine.developerTeachingMode {
                                Button("结束示范") { engine.stopDeveloperTeaching() }
                                    .buttonStyle(.bordered)
                            }
                        }
                        if engine.developerTeachingMode {
                            Text("棋盘已进入教学模式：轮流点击即可代替黑白双方落子，不会启动电脑对局。")
                                .font(.caption)
                            TextField("阵法名称", text: $name)
                                .textFieldStyle(.roundedBorder)
                            TextField("用途：进攻、封堵或反制", text: $purpose)
                                .textFieldStyle(.roundedBorder)
                            TextField("训练目标", text: $objective)
                                .textFieldStyle(.roundedBorder)
                            Button("校验并签名保存阵法") {
                                engine.saveDeveloperLesson(
                                    name: name, purpose: purpose, objective: objective
                                )
                            }
                            .buttonStyle(.borderedProminent)
                        }
                        Divider()
                        Text("已验证保存 \(engine.savedDeveloperLessons) 条阵法")
                            .font(.subheadline.weight(.semibold))
                        ForEach(engine.developerLessonList) { lesson in
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(lesson.name).font(.subheadline.weight(.semibold))
                                    Text(lesson.purpose).font(.caption)
                                    Text("目标：\(lesson.objective) · \(lesson.moves.count) 手")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Button("删除", role: .destructive) {
                                    engine.removeDeveloperLesson(id: lesson.id)
                                }
                                .font(.caption)
                            }
                            .padding(.vertical, 4)
                        }
                        Divider()
                        Text("原版私有训练数据库")
                            .font(.subheadline.weight(.semibold))
                        Button(engine.isImportingLegacyLearning
                               ? "正在验证并导入" : "选择 VeilLink .vltrain.json") {
                            choosingPackage = true
                        }
                        .disabled(engine.isImportingLegacyLearning || engine.isNativeTraining
                                  || engine.isBootstrappingSeed)
                        .buttonStyle(.bordered)
                        if let report = engine.legacyImportStatus {
                            Text(report).font(.caption).foregroundStyle(.secondary)
                        }
                        Button("锁定开发者会话", role: .destructive) {
                            if engine.developerTeachingMode { engine.stopDeveloperTeaching() }
                            authorization.revoke()
                        }
                        .buttonStyle(.bordered)
                    } else {
                        Label("未授权：棋谱可以正常对局，但私有训练导入被锁定。", systemImage: "lock.shield")
                            .font(.caption)
                        Button("验证设备持有人身份") {
                            Task { _ = await authorization.authorize() }
                        }
                        .buttonStyle(.borderedProminent)
                        if let failure = authorization.failure {
                            Text(failure).font(.caption).foregroundStyle(.orange)
                        }
                    }
                    if let message = engine.developerMessage {
                        Text(message).font(.caption).foregroundStyle(.secondary)
                    }
                }
                .padding(20)
            }
            .navigationTitle("开发者学习室")
            .navigationBarTitleDisplayMode(.inline)
            .fileImporter(isPresented: $choosingPackage,
                          allowedContentTypes: [.json]) { result in
                guard authorization.isAuthorized else { return }
                if case let .success(url) = result {
                    engine.importLegacyLearning(from: url)
                }
            }
        }
    }
}
