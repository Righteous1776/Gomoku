import Foundation

/// A model family/version is NOT a search-budget multiplier.
/// Training releases (including a future R29 checkpoint) MUST receive a new
/// immutable version ONLY after independently verified artifact promotion.
enum EclipseModelID: String, CaseIterable, Sendable, Identifiable {
    case luna10 = "eclipse-1.0-luna"
    case terra10 = "eclipse-1.0-terra"
    case sol10 = "eclipse-1.0-sol"
    case astra10 = "eclipse-1.0-astra"
    // V9-trained 26D candidate rankers are a NEW generation, not aliases
    // for legacy 1.0/1.1/1.2 compute budgets. Keep their IDs independently.
    case astra20 = "eclipse-2.0-astra"
    case sol20 = "eclipse-2.0-sol"
    // Genuine R07-249 research forest, experimental but actually executable.
    case astra30 = "eclipse-3.0-astra"

    static let currentDefault: Self = .terra10
    static let selectionKey = "gomoku.eclipse.selected-model-id.v1"
    // 1.x keeps the previously released historical Swift model library.
    // 2.0 becomes selectable ONLY after a real matching trained checkpoint
    // has been loaded, not simply because a V9 research file exists.
    static let featured: [Self] = [.astra10, .sol10, .terra10, .luna10]

    var requiresVerifiedCheckpoint: Bool {
        self == .astra20 || self == .sol20 || self == .astra30
    }

    static func featuredIncludingVerified(_ verified: Self?) -> [Self] {
        guard let verified, verified.requiresVerifiedCheckpoint else {
            return featured
        }
        return [verified] + featured
    }

    /// Both independently attested 2.0 generations must be presented together.
    /// Keep the single-model overload above for older history and test clients.
    static func featuredIncludingVerified(_ verified: [Self]) -> [Self] {
        let candidates: [Self] = [.astra30, .astra20, .sol20]
        return candidates.filter { verified.contains($0) } + featured
    }

    enum Backend: String, Sendable {
        case classicSwift = "classic-swift"
        case trainedUnifiedSwift = "trained-unified-swift"
        case verifiedTrainedCpp = "verified-trained-cpp"
    }

    var id: String { rawValue }
    var name: String {
        switch self {
        case .luna10: return "1.0 Luna"
        case .terra10: return "1.0 Terra"
        case .sol10: return "1.0 Sol"
        case .astra10: return "1.0 Astra"
        case .astra20: return "2.0 Astra"
        case .sol20: return "2.0 Sol"
        case .astra30: return "3.0 Astra"
        }
    }
    var family: String {
        switch self {
        case .luna10: return "Luna"
        case .terra10: return "Terra"
        case .sol10, .sol20: return "Sol"
        case .astra10, .astra20, .astra30: return "Astra"
        }
    }
    var backend: Backend {
        switch self {
        case .luna10: return .classicSwift
        case .terra10, .sol10, .astra10: return .trainedUnifiedSwift
        case .astra20, .sol20, .astra30: return .verifiedTrainedCpp
        }
    }
    var usesTrainedUnifiedSearch: Bool { backend == .trainedUnifiedSwift }
    var defaultComputeTier: EclipseComputeTier {
        self == .astra10 || self == .astra20 || self == .astra30 ? .extreme : .standard
    }
    var description: String {
        switch self {
        case .luna10: return "经典轻量型 · 独立 Swift 传统搜索"
        case .terra10: return "均衡型 · 训练排序与稳定攻防"
        case .sol10: return "策略型 · 强迫搜索与中盘对抗"
        case .astra10: return "旗舰算力型 · 深层组合与强迫搜索"
        case .astra20: return "第二代旗舰 · V9 314 树训练检查点"
        case .sol20: return "第二代蒸馏型 · V9 160 树独立权重"
        case .astra30: return "第三代实验旗舰 · R07-249 真权重 · 34D 兼容特征待完整验证"
        }
    }
    var backendDescription: String {
        switch backend {
        case .classicSwift: return "Swift Classic · 经典启发式"
        case .trainedUnifiedSwift: return "Swift Unified · 原生 R10/R12/R13"
        case .verifiedTrainedCpp: return "C++20 V2 · 必须验证已加载模型"
        }
    }
    var artifactKind: String {
        if self == .astra30 { return "cpp-lightgbm-r07-249-34d-experimental" }
        switch backend {
        case .classicSwift: return "native-classic-policy-v1"
        case .trainedUnifiedSwift: return "native-unified-r10-policy-v1"
        case .verifiedTrainedCpp: return "cpp-lightgbm-ranker-26d-v9"
        }
    }
    var recommendedBudgetMilliseconds: Int {
        GomokuBotBudget.forDifficulty(
            EclipseModelSelection(model: self, compute: defaultComputeTier).legacyDifficulty,
            profileLabel: "HIGH"
        ).timeLimitMilliseconds
    }

    static func fromStoredIdentifier(_ value: String?) -> Self? {
        guard let value else { return nil }
        return EclipseModelSelection.fromArchiveValue(value)?.model
    }
    static func fromLegacyDifficulty(_ legacy: BoardBotDifficulty) -> Self {
        EclipseModelSelection.fromLegacyDifficulty(legacy).model
    }
    static func fromArchiveValue(_ value: String) -> Self? {
        EclipseModelSelection.fromArchiveValue(value)?.model
    }
}

/// An explicit, orthogonal choice: screenshot-style model + effort + speed.
/// Compute changes *actual* GomokuBotBudget and UnifiedSearch limits, not a
/// display label. The original seven native tiers remain intact internally.
enum EclipseComputeTier: String, CaseIterable, Sendable, Identifiable {
    case light, standard, high, extreme

    static let selectionKey = "gomoku.eclipse.compute-tier.v1"
    var id: String { rawValue }
    var title: String {
        switch self {
        case .light: return "轻度"
        case .standard: return "标准"
        case .high: return "高"
        case .extreme: return "极高"
        }
    }
}

struct EclipseModelSelection: Equatable, Sendable {
    let model: EclipseModelID
    let compute: EclipseComputeTier

    var legacyDifficulty: BoardBotDifficulty {
        switch model {
        case .luna10:
            switch compute {
            case .light, .standard: return .relaxed
            case .high: return .balanced
            case .extreme: return .advanced
            }
        case .terra10:
            switch compute {
            case .light: return .relaxed
            case .standard: return .balanced
            case .high: return .advanced
            case .extreme: return .master
            }
        case .sol10, .sol20:
            switch compute {
            case .light: return .balanced
            case .standard: return .advanced
            case .high: return .master
            case .extreme: return .grandmaster
            }
        case .astra10, .astra20, .astra30:
            switch compute {
            case .light: return .master
            case .standard: return .grandmaster
            case .high: return .legendary
            case .extreme: return .zenith
            }
        }
    }

    var budgetMilliseconds: Int {
        GomokuBotBudget.forDifficulty(
            legacyDifficulty, profileLabel: "HIGH"
        ).timeLimitMilliseconds
    }

    /// A separate model identity and compute option within one existing archive
    /// String, preserving the signed Match V1 JSON shape and all older records.
    var archiveValue: String { model.rawValue + "|" + compute.rawValue }

    static func fromArchiveValue(_ value: String) -> Self? {
        if value.contains("|") {
            let parts = value.split(separator: "|", omittingEmptySubsequences: false)
            guard parts.count == 2,
                  let model = EclipseModelID(rawValue: String(parts[0])),
                  let compute = EclipseComputeTier(rawValue: String(parts[1]))
            else { return nil }
            return Self(model: model, compute: compute)
        }
        if let model = EclipseModelID(rawValue: value) {
            return Self(model: model, compute: model.defaultComputeTier)
        }
        // R14 draft archive identities remain readable without changing bytes.
        switch value {
        case "eclipse-1.1-sol": return Self(model: .sol10, compute: .high)
        case "eclipse-1.1-astra": return Self(model: .astra10, compute: .high)
        case "eclipse-1.2-astra": return Self(model: .astra10, compute: .extreme)
        default: break
        }
        guard let legacy = BoardBotDifficulty(rawValue: value) else { return nil }
        return fromLegacyDifficulty(legacy)
    }

    static func fromLegacyDifficulty(_ legacy: BoardBotDifficulty) -> Self {
        switch legacy {
        case .relaxed: return Self(model: .luna10, compute: .standard)
        case .balanced: return Self(model: .terra10, compute: .standard)
        case .advanced: return Self(model: .sol10, compute: .standard)
        case .master: return Self(model: .sol10, compute: .high)
        case .grandmaster: return Self(model: .astra10, compute: .standard)
        case .legendary: return Self(model: .astra10, compute: .high)
        case .zenith: return Self(model: .astra10, compute: .extreme)
        }
    }
}
