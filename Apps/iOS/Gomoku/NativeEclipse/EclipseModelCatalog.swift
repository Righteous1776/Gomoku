import Foundation

/// ECLIPSE versioned, offline model-policy registry.
///
/// A model identity selects an actual execution path AND an immutable native
/// search policy; it is not merely a renamed difficulty button.
/// R14 ships one Classic-Swift backend (Luna) and six versions using the original
/// trained Swift R10/R12/R13 unified backend. These are independently selectable
/// SEARCH-POLICY models sharing a core, NOT seven separately fitted neural
/// checkpoints. Experimental C++ is NOT silently advertised as a production
/// model until full original Swift noninferiority is certified.
enum EclipseModelID: String, CaseIterable, Sendable, Identifiable {
    case luna10 = "eclipse-1.0-luna"
    case terra10 = "eclipse-1.0-terra"
    case sol10 = "eclipse-1.0-sol"
    case sol11 = "eclipse-1.1-sol"
    case astra10 = "eclipse-1.0-astra"
    case astra11 = "eclipse-1.1-astra"
    case astra12 = "eclipse-1.2-astra"

    static let currentDefault: Self = .terra10
    static let selectionKey = "gomoku.eclipse.selected-model-id.v1"

    enum Backend: String, Sendable {
        case classicSwift = "classic-swift"
        case trainedUnifiedSwift = "trained-unified-swift"
    }

    /// Strongest first, like a model chooser; not alphabetical.
    static let featured: [Self] = [
        .astra12, .astra11, .astra10, .sol11,
        .sol10, .terra10, .luna10
    ]

    var id: String { rawValue }
    var name: String {
        switch self {
        case .luna10: return "1.0 Luna"
        case .terra10: return "1.0 Terra"
        case .sol10: return "1.0 Sol"
        case .sol11: return "1.1 Sol"
        case .astra10: return "1.0 Astra"
        case .astra11: return "1.1 Astra"
        case .astra12: return "1.2 Astra"
        }
    }
    var family: String {
        switch self {
        case .luna10: return "Luna"
        case .terra10: return "Terra"
        case .sol10, .sol11: return "Sol"
        case .astra10, .astra11, .astra12: return "Astra"
        }
    }
    var legacyDifficulty: BoardBotDifficulty {
        switch self {
        case .luna10: return .relaxed
        case .terra10: return .balanced
        case .sol10: return .advanced
        case .sol11: return .master
        case .astra10: return .grandmaster
        case .astra11: return .legendary
        case .astra12: return .zenith
        }
    }
    var backend: Backend {
        self == .luna10 ? .classicSwift : .trainedUnifiedSwift
    }
    var description: String {
        switch self {
        case .luna10:
            return "轻量经典推演 · 独立启用原生经典搜索"
        case .terra10:
            return "均衡防守 · 本地学习与训练型统一搜索"
        case .sol10:
            return "进阶攻防 · 扩展候选与强迫应手搜索"
        case .sol11:
            return "深入策略 · 增强搜索宽度和连续应手"
        case .astra10:
            return "高强度推演 · 宗师基础的 2× 预算"
        case .astra11:
            return "深层推演 · 宗师基础的 4× 预算"
        case .astra12:
            return "旗舰推演 · 宗师基础的 6× 预算"
        }
    }
    var backendDescription: String {
        backend == .classicSwift
            ? "Swift Classic · 原生规则与启发式"
            : "Swift Unified · R10 训练排序 + R12/R13"
    }

    /// Explicit time budget at full compute for consistent model comparisons.
    /// This is not an observed battery drain, a guaranteed latency, or an Elo.
    var fullComputeBudgetMilliseconds: Int {
        GomokuBotBudget.forDifficulty(legacyDifficulty, profileLabel: "HIGH")
            .timeLimitMilliseconds
    }

    /// The actual dispatch decision used by GomokuBot.chooseMove.
    var usesTrainedUnifiedSearch: Bool {
        backend == .trainedUnifiedSwift
    }

    /// Persist stable model IDs, not mutable display strings.
    static func fromStoredIdentifier(_ value: String?) -> Self? {
        guard let value else { return nil }
        return Self(rawValue: value)
    }

    /// Archive migration: earlier games stored seven original tier raw values.
    /// No editing old match bytes, so signed local match history stays intact.
    static func fromArchiveValue(_ value: String) -> Self? {
        if let model = Self(rawValue: value) { return model }
        guard let legacy = BoardBotDifficulty(rawValue: value) else { return nil }
        return fromLegacyDifficulty(legacy)
    }

    static func fromLegacyDifficulty(_ legacy: BoardBotDifficulty) -> Self {
        switch legacy {
        case .relaxed: return .luna10
        case .balanced: return .terra10
        case .advanced: return .sol10
        case .master: return .sol11
        case .grandmaster: return .astra10
        case .legendary: return .astra11
        case .zenith: return .astra12
        }
    }

    /// Versioned release/implementation metadata. A new trained checkpoint
    /// must get a NEW immutable model ID, not replace an existing one in place.
    var artifactKind: String {
        backend == .classicSwift
            ? "native-classic-policy-v1"
            : "native-unified-r10-policy-v1"
    }
}
