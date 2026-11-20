import SwiftUI

/// Standalone functional shell. Exact VeilLink instrument UI transplant is a P3 release gate.
struct InstrumentHomeView: View {
    @StateObject private var engine = NativeGomokuAppController()
    @Environment(\.colorScheme) private var scheme
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var panel: Color { scheme == .dark ? Color(red: 0.15, green: 0.17, blue: 0.20) : Color(red: 0.89, green: 0.90, blue: 0.89) }
    private var surface: Color { scheme == .dark ? Color(red: 0.21, green: 0.24, blue: 0.27) : Color(red: 0.95, green: 0.95, blue: 0.93) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("GOMOKU").font(.system(size: 31, weight: .bold, design: .rounded))
                        Text("ECLIPSE · INSTRUMENT CONSOLE")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .tracking(1.5).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle().fill(engine.isThinking ? .orange : Color(white: 0.70))
                        .frame(width: 12, height: 12)
                        .shadow(color: engine.isThinking ? .orange.opacity(0.4) : .clear, radius: 5)
                        .accessibilityLabel(engine.isThinking ? "AI searching" : "Engine ready")
                }
                // One upper identity/compute unit. No lower telemetry dashboard.
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("ECLIPSE / NATIVE INTELLIGENCE")
                            .font(.system(size: 11, weight: .semibold, design: .monospaced))
                            .foregroundColor(.orange)
                        Spacer()
                        Text(engine.isThinking ? "COMPUTE" : "READY")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.75))
                    }
                    Text(statusText)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                        .foregroundColor(.white)
                    if engine.isThinking, let started = engine.searchStartedAt {
                        TimelineView(.periodic(from: .now,
                            by: scenePhase == .active && !reduceMotion ? 0.5 : 1.0)) { context in
                            Text(String(format: "REAL CLOCK  T+%.1fs",
                                        max(0, context.date.timeIntervalSince(started))))
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .foregroundColor(.orange)
                        }
                    } else {
                        Text("REAL CLOCK / IDLE")
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundColor(Color(white: 0.65))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(red: 0.08, green: 0.085, blue: 0.09),
                            in: RoundedRectangle(cornerRadius: 15))
                .overlay(RoundedRectangle(cornerRadius: 15)
                    .strokeBorder(Color(white: 0.33), lineWidth: 0.8))
                .accessibilityIdentifier("gomoku.eclipse.upper-compute-console")
                BoardInstrumentView(board: engine.board, enabled: engine.status == 0 && !engine.isThinking && engine.toMove == engine.humanColor) {
                    engine.play($0)
                }
                HStack(spacing: 12) {
                    Button("NEW GAME") { engine.reset() }
                        .buttonStyle(InstrumentButtonStyle())
                    Button(engine.humanIsBlack ? "BLACK · FIRST" : "WHITE · SECOND") { engine.toggleSide() }
                        .buttonStyle(InstrumentButtonStyle())
                }
                VStack(alignment: .leading, spacing: 8) {
                    Picker("ECLIPSE 难度", selection: $engine.difficulty) {
                        ForEach(BoardBotDifficulty.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .pickerStyle(.menu)
                    .accessibilityIdentifier("gomoku.eclipse.seven-tiers")

                    Picker("搜索模式", selection: $engine.searchMode) {
                        ForEach(BoardSearchMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("gomoku.eclipse.search-mode")
                }
                HStack(spacing: 12) {
                    Button(engine.isNativeTraining ? "训练进行中" : "真实自对弈 1 局") {
                        engine.beginNativeSelfPlay(games: 1)
                    }
                    .disabled(engine.isNativeTraining)
                    .buttonStyle(InstrumentButtonStyle())
                    Text("已保存训练：\(engine.trainedGames) 局")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                if let warning = engine.trainingWarning ?? engine.archiveWarning {
                    Text(warning).font(.caption2).foregroundStyle(.orange)
                }
                Text("ENGINE: Original Swift ECLIPSE GomokuBot (mandatory tactical gates). Native learning imports, exact instrumentAuto and release parity still require validation.")
                    .font(.caption2).foregroundStyle(.secondary)
            }
            .padding(18)
            .frame(maxWidth: 680)
            .frame(maxWidth: .infinity)
        }
        .background(panel.ignoresSafeArea())
    }

    private var statusText: String {
        switch engine.status {
        case 1: return "BLACK WINS"
        case 2: return "WHITE WINS"
        case 3: return "DRAW"
        default: return engine.isThinking ? "AI THINKING" : engine.toMove == 1 ? "BLACK TO MOVE" : "WHITE TO MOVE"
        }
    }
}

private struct InstrumentButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .bold, design: .monospaced))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.12)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
