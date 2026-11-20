import Foundation

// Original seven-level AI difficulty and opt-in economy search definitions.
enum BoardBotDifficulty: String, CaseIterable, Identifiable, Sendable {
    case relaxed
    case balanced
    case advanced
    case master
    case grandmaster
    case legendary
    case zenith

    static let xiangqiCases: [BoardBotDifficulty] = [.relaxed, .balanced, .advanced, .master]
    var isExtendedGomokuTier: Bool { self == .grandmaster || self == .legendary || self == .zenith }
    var searchBudgetMultiplier: Int {
        switch self {
        case .grandmaster: return 2
        case .legendary: return 4
        case .zenith: return 6
        default: return 1
        }
    }

    var id: String { rawValue }

    var title: String {
        switch self {
        case .relaxed: return "轻松"
        case .balanced: return "均衡"
        case .advanced: return "进阶"
        case .master: return "宗师"
        case .grandmaster: return "棋圣 · 2×"
        case .legendary: return "传奇 · 4×"
        case .zenith: return "天元 · 6×"
        }
    }

    var detail: String {
        switch self {
        case .relaxed: return "保留明显容错，适合入门练习"
        case .balanced: return "稳定策略与本地学习"
        case .advanced: return "更宽候选、更深反击搜索"
        case .master: return "更宽候选与更深搜索；可手动选择节能模式"
        case .grandmaster: return "以宗师为基准，最多 2 倍搜索预算；不是棋力倍数"
        case .legendary: return "以宗师为基准，最多 4 倍搜索预算；不是棋力倍数"
        case .zenith: return "以宗师为基准，最多 6 倍搜索预算；不是棋力倍数"
        }
    }
}

/// User-directed compute preference: never silently downshift search solely
/// because hardware is classified as iPhone 7 / SE1 / LEGACY-COMPACT.
/// Full depth is the default on ALL devices. Economy is opt-in and can be
/// changed at any time without modifying a saved match or a model archive.
enum BoardSearchMode: String, CaseIterable, Identifiable, Sendable {
    case full
    case economy

    var id: String { rawValue }
    var title: String { self == .full ? "深度搜索" : "节能搜索" }

    static func restore(_ storedValue: String?) -> BoardSearchMode {
        BoardSearchMode(rawValue: storedValue ?? "") ?? .full
    }

    /// Explicit engine budget presets; not a device detection result.
    var budgetProfileLabel: String {
        self == .full ? "HIGH" : "LEGACY-COMPACT"
    }
}
