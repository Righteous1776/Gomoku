import SwiftUI

/// Standalone functional shell. Exact VeilLink instrument UI transplant is a P3 release gate.
struct InstrumentHomeView: View {
    @StateObject private var engine = EngineBridge()
    @Environment(\.colorScheme) private var scheme

    private var panel: Color { scheme == .dark ? Color(red: 0.15, green: 0.17, blue: 0.20) : Color(red: 0.89, green: 0.90, blue: 0.89) }
    private var surface: Color { scheme == .dark ? Color(red: 0.21, green: 0.24, blue: 0.27) : Color(red: 0.95, green: 0.95, blue: 0.93) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("GOMOKU").font(.system(.largeTitle, design: .rounded, weight: .bold))
                        Text("ECLIPSE · INSTRUMENT CONSOLE")
                            .font(.system(size: 11, design: .monospaced, weight: .medium))
                            .tracking(1.5).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Circle().fill(engine.isThinking ? .orange : .green)
                        .frame(width: 12, height: 12)
                        .shadow(color: engine.isThinking ? .orange.opacity(0.5) : .green.opacity(0.3), radius: 5)
                        .accessibilityLabel(engine.isThinking ? "AI searching" : "Engine ready")
                }
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("ENGINE STATUS").font(.caption2.monospaced()).foregroundStyle(.secondary)
                        Text(statusText).font(.system(.headline, design: .monospaced))
                    }
                    Spacer()
                    Text("15 × 15").font(.system(.caption, design: .monospaced))
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(surface, in: RoundedRectangle(cornerRadius: 16))
                .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.primary.opacity(0.08)))
                BoardInstrumentView(board: engine.board, enabled: engine.status == 0 && !engine.isThinking && engine.toMove == engine.humanColor) {
                    engine.play($0)
                }
                HStack(spacing: 12) {
                    Button("NEW GAME") { engine.reset() }
                        .buttonStyle(InstrumentButtonStyle())
                    Button(engine.humanIsBlack ? "BLACK · FIRST" : "WHITE · SECOND") { engine.toggleSide() }
                        .buttonStyle(InstrumentButtonStyle())
                }
                Text("ENGINE: C++ experimental baseline. Source-fidelity ECLIPSE migration and strength validation are mandatory before release.")
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
            .font(.system(size: 12, design: .monospaced, weight: .bold))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, minHeight: 50)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(.primary.opacity(0.12)))
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}
