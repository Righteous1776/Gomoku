import Foundation

// HEADLESS TEST ONLY: empty learning facade for compilation of the unchanged
// production GomokuBot.swift. The original model is defined in
// Legacy/Original/VeilLink/Agent/Games/AdaptiveBoardLearning.swift.
// This deliberately does NOT read/claim to reproduce any owner-trained state.
// It has the same all-zero behavior as original Snapshot.empty.
struct AdaptiveBoardLearningSnapshot: Sendable {
    static let empty = AdaptiveBoardLearningSnapshot()
    let trainingLevel: Int = 0
    func bonus(position: String, action: String) -> Int { 0 }
    func rootAdjustment(action: String) -> Int { 0 }
    func predictedHumanReply(afterAIAction action: String) -> AdaptiveBoardPrediction? { nil }
    var hasSequenceEvidence: Bool { false }
}

struct AdaptiveBoardPrediction: Equatable, Sendable {
    let action: String
    let evidence: Int
}

enum AdaptiveBoardGameResult: String, Codable, Sendable {
    case humanWon
    case aiWon
    case draw
    case unfinished
}

// Copied from the original AdaptiveBoardPosition.gomoku function,
// preserving the FNV-1a position key used by native search.
enum AdaptiveBoardPosition {
    static func gomoku(_ state: GomokuState) -> String {
        var bytes: [UInt8] = [state.currentPlayer == .host ? 1 : 2]
        bytes.reserveCapacity(GomokuState.size * GomokuState.size + 1)
        for index in 0..<(GomokuState.size * GomokuState.size) {
            bytes.append(UInt8(state.value(at: index)))
        }
        var value: UInt64 = 14_695_981_039_346_656_037
        for byte in bytes {
            value ^= UInt64(byte)
            value &*= 1_099_511_628_211
        }
        return "g:" + String(value, radix: 16)
    }
}
