import Foundation

/// SwiftUI stays the product owner; this is a non-mutating, versioned C ABI
/// parity probe, NOT a replacement for the original GomokuBot search.
/// A C++ engine cannot become the default just because its rules match.
enum EclipseCppRulesParityProbe {
    static let expectedABIVersion: Int32 = 1

    struct Snapshot: Equatable {
        let board: [UInt8]
        let toMove: Int32
        let status: Int32
    }

    static func replay(_ history: [Int]) -> Snapshot? {
        guard eg_rules_abi_version() == expectedABIVersion,
              history.count <= GomokuState.size * GomokuState.size,
              history.allSatisfy({ (0..<225).contains($0) }) else { return nil }
        let source = history.map(Int32.init)
        var cells = [UInt8](repeating: 0, count: 225)
        var side: Int32 = 0
        var status: Int32 = -1
        let accepted = source.withUnsafeBufferPointer { sequence in
            cells.withUnsafeMutableBufferPointer { board in
                eg_rules_replay_v1(
                    sequence.baseAddress, Int32(sequence.count),
                    board.baseAddress, Int32(board.count),
                    &side, &status
                )
            }
        }
        guard accepted == 1 else { return nil }
        return Snapshot(board: cells, toMove: side, status: status)
    }
}
