import Foundation
import CryptoKit

/// Runtime compute policy supplied by the specialized TRAINING agent.
///
/// This is not a rebranded seven-tier budget table. An absent time/node limit
/// means no imposed wall-clock/node cut-off; the trainer controls depth, width,
/// and the stopping rule for its own checkpoint. Existing Swift policies
/// remain a read-only reference until a VERIFIED trainer artifact is supplied.
struct EclipseTrainerComputePolicy: Codable, Sendable, Equatable {
    enum Mode: String, Codable, Sendable { case adaptive, budgeted }

    let mode: Mode
    let maxWallTimeMilliseconds: Int?
    let maxNodes: Int?
    let maxDepth: Int
    let rootWidth: Int
    let replyWidth: Int
    let continuationWidth: Int
    let forcedLineDepth: Int
    let candidateRadius: Int

    enum CodingKeys: String, CodingKey {
        case mode
        case maxWallTimeMilliseconds = "max_wall_time_ms"
        case maxNodes = "max_nodes"
        case maxDepth = "max_depth"
        case rootWidth = "root_width"
        case replyWidth = "reply_width"
        case continuationWidth = "continuation_width"
        case forcedLineDepth = "forced_line_depth"
        case candidateRadius = "candidate_radius"
    }

    var isValid: Bool {
        let validTime = maxWallTimeMilliseconds.map { $0 > 0 } ?? true
        let validNodes = maxNodes.map { $0 > 0 } ?? true
        let modeMatchesTime = mode == .adaptive
            ? maxWallTimeMilliseconds == nil
            : maxWallTimeMilliseconds != nil
        return validTime && validNodes && modeMatchesTime
            && (1...225).contains(maxDepth)
            && (1...225).contains(rootWidth)
            && (1...225).contains(replyWidth)
            && (0...225).contains(continuationWidth)
            && (0...225).contains(forcedLineDepth)
            && (1...14).contains(candidateRadius)
    }

    /// NULL / nil is encoded as an explicit null to match Python's audited
    /// json.dumps(sort_keys=True,separators=(',',':')) digest exactly.
    var canonicalData: Data? {
        guard isValid else { return nil }
        let fields: [String: Any] = [
            "mode": mode.rawValue,
            "max_wall_time_ms": maxWallTimeMilliseconds.map { $0 as Any } ?? NSNull(),
            "max_nodes": maxNodes.map { $0 as Any } ?? NSNull(),
            "max_depth": maxDepth,
            "root_width": rootWidth,
            "reply_width": replyWidth,
            "continuation_width": continuationWidth,
            "forced_line_depth": forcedLineDepth,
            "candidate_radius": candidateRadius
        ]
        return try? JSONSerialization.data(withJSONObject: fields, options: [.sortedKeys])
    }

    var sha256: String? {
        canonicalData.map { data in
            SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        }
    }

    /// Use the agent's concrete search geometry exactly, not an old
    /// difficulty-based multiplier, 5.7-second ceiling or reinforcement clip.
    func budget() -> GomokuBotBudget {
        GomokuBotBudget(
            candidateRadius: candidateRadius,
            rootCandidateLimit: rootWidth,
            replyCandidateLimit: replyWidth,
            continuationCandidateLimit: continuationWidth,
            timeLimitMilliseconds: maxWallTimeMilliseconds ?? 0
        )
    }

    func unifiedLimits() -> VeilGomokuUnifiedSearch.Limits {
        var limits = VeilGomokuUnifiedSearch.Limits()
        limits.maxDepth = maxDepth
        limits.maxNodes = maxNodes ?? 0
        limits.maxMilliseconds = maxWallTimeMilliseconds ?? 0
        limits.width = rootWidth
        limits.forcedLineDepth = forcedLineDepth
        limits.candidateRadius = candidateRadius
        return limits
    }
}

/// Only an integration layer that can prove checkpoint bytes were really
/// loaded by the candidate may provide this token. The policy digest must
/// match those loaded bytes and the trainer handoff; naming alone is rejected.
/// The currently public release has NO R29 token, so it uses original Swift.
struct EclipseVerifiedTrainerExecution: Sendable {
    let model: EclipseModelID
    let trainingRevision: String
    let checkpointSHA256: String
    let computePolicy: EclipseTrainerComputePolicy

    init?(
        model: EclipseModelID,
        trainingRevision: String,
        checkpointSHA256: String,
        loadedCheckpointSHA256: String,
        computePolicy: EclipseTrainerComputePolicy,
        approvedComputePolicySHA256: String,
        loadedComputePolicySHA256: String
    ) {
        let hex = CharacterSet(charactersIn: "0123456789abcdef")
        guard trainingRevision.first == "R",
              trainingRevision.dropFirst().allSatisfy({ $0.isNumber }),
              !trainingRevision.dropFirst().isEmpty,
              checkpointSHA256.count == 64,
              checkpointSHA256.unicodeScalars.allSatisfy(hex.contains),
              checkpointSHA256 == loadedCheckpointSHA256,
              let digest = computePolicy.sha256,
              digest == approvedComputePolicySHA256,
              digest == loadedComputePolicySHA256
        else { return nil }
        self.model = model
        self.trainingRevision = trainingRevision
        self.checkpointSHA256 = checkpointSHA256
        self.computePolicy = computePolicy
    }
}
