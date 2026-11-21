import Foundation

/// Read-only, versioned presentation projection of measurements returned
/// by the active ECLIPSE engine. Never holds hypothetical moves or private
/// training positions. A nil measurement means unsupported, NOT zero.
struct EclipseThinkingHUDSnapshot: Equatable {
    static let version = 1

    enum Context: Equatable {
        case formal
        case teaching
        case postgame

        /// Future PV and tactical overlays must pass this check.
        /// Formal competition cannot leak AI candidates while thinking.
        var permitsUncommittedCandidates: Bool {
            self != .formal
        }
    }

    let searchID: UUID?
    let positionRevision: Int
    let context: Context
    let isSearching: Bool
    let backend: String
    /// This is the actual engine identity, not the selected UI model.
    let executedModel: String?
    let checkpointSHA256: String?
    let computePolicySHA256: String?
    let elapsedMilliseconds: Int?
    let visitedNodes: Int?
    let completedDepth: Int?
    let stopReason: String?

    /// Actual best move of a COMPLETED native depth, not a proven win.
    /// Never populated from speculative or partially searched root branches.
    var verifiedTeachingCandidate: Int? = nil
    /// Actual ranked C++ root shortlist, truncated to 16. Only authorized
    /// teaching may render it and the board controller rechecks legality.
    var nativeRootRanks: [Int] = []
    /// A validated *prefix*, not a guaranteed full-depth PV or proof tree.
    /// Caller has replayed every move on the actual 15×15 board.
    var nativePVPrefix: [Int] = []
    var nativePVDepth: Int? = nil

    var visibleTeachingPVPrefix: [Int] {
        guard context == .teaching, isSearching,
              let depth = nativePVDepth, depth > 0,
              !nativePVPrefix.isEmpty,
              nativePVPrefix.count <= depth,
              nativePVPrefix.count <= 16 else { return [] }
        return nativePVPrefix
    }

    var visibleTeachingRanks: [Int] {
        guard context == .teaching, isSearching,
              !nativeRootRanks.isEmpty,
              nativeRootRanks.count <= 16,
              Set(nativeRootRanks).count == nativeRootRanks.count,
              nativeRootRanks.allSatisfy({ (0..<225).contains($0) })
        else { return [] }
        return nativeRootRanks
    }

    /// Defense in depth: a formal-game caller cannot accidentally reveal an
    /// unplayed move even if an invalid fixture sets the underlying field.
    var visibleTeachingCandidate: Int? {
        guard context == .teaching, isSearching,
              let index = verifiedTeachingCandidate,
              (0..<225).contains(index), (completedDepth ?? 0) > 0 else {
            return nil
        }
        return index
    }

    var averageNPS: Int? {
        guard let visitedNodes, let elapsedMilliseconds,
              visitedNodes > 0, elapsedMilliseconds >= 500 else { return nil }
        return Int(Double(visitedNodes) * 1000.0 / Double(elapsedMilliseconds))
    }
    var shortStatus: String {
        if isSearching { return "搜索中 · 阶段未提供" }
        if stopReason != nil || elapsedMilliseconds != nil { return "本步已结束" }
        return "等待搜索"
    }
    static func nativeStopReason(_ raw: Int32?) -> String? {
        guard let raw else { return nil }
        switch raw {
        case Int32(EG_SEARCH_REASON_COMPLETE):
            return "完成配置的搜索深度"
        case Int32(EG_SEARCH_REASON_FORCED_WIN):
            return "直接获胜落点 / 强制终结"
        case Int32(EG_SEARCH_REASON_FORCED_BLOCK):
            return "已识别立即必防"
        case Int32(EG_SEARCH_REASON_ONLY_MOVE):
            return "仅有一个合法候选"
        case Int32(EG_SEARCH_REASON_NO_MOVE):
            return "无合法落子"
        case Int32(EG_SEARCH_REASON_TIME_LIMIT):
            return "搜索预算耗尽（时间或节点）"
        case Int32(EG_SEARCH_REASON_CANCELLED):
            return "引擎收到取消信号"
        default: return nil
        }
    }
}

/// The *verified* run identity. Isolated from any selected-model UI label.
/// A nil checkpoint SHA means no loaded C++ V9 model is being claimed.
struct EclipseThinkingRunIdentity: Equatable {
    let id: UUID
    let positionRevision: Int
    let backend: String
    let modelName: String?
    let checkpointSHA256: String?
    let computePolicySHA256: String?
}

/** In-memory measured native decision latency, tied to ONE attested model SHA
    and exact compute policy SHA. No private board position is stored.
    A 20-sample floor avoids presenting a single turn as a P95 distribution. */
enum EclipseNativeLatencyStatistics {
    struct Summary: Equatable {
        let count: Int
        let p50Milliseconds: Int
        let p95Milliseconds: Int
    }

    static func summarize(_ samples: [Int]) -> Summary? {
        guard samples.count >= 20,
              samples.allSatisfy({ $0 > 0 }) else { return nil }
        let sorted = samples.sorted()
        func nearestRank(_ quantile: Double) -> Int {
            let index = max(0, min(sorted.count - 1,
                Int(ceil(quantile * Double(sorted.count))) - 1))
            return sorted[index]
        }
        return Summary(count: sorted.count,
                       p50Milliseconds: nearestRank(0.5),
                       p95Milliseconds: nearestRank(0.95))
    }
}
