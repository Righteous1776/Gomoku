import Foundation

/// Strictly measured native search milestones. No simulated depths, scores,
/// branch guesses or user/opponent coaching data. The worker writes under a
/// lock; views read a sanitized (depth, nodes) pair at a bounded frame rate.
final class VeilEclipseMeasuredMetricsStore: @unchecked Sendable {
    private let lock = NSLock()
    private var session: String?
    private var turn: Int = -1
    private var token: UUID?
    private var lastNodes = 0
    private var lastDepth = 0

    @discardableResult
    func begin(sessionID: String, turn: Int) -> UUID {
        lock.lock()
        defer { lock.unlock() }
        let id = UUID()
        session = sessionID
        self.turn = turn
        token = id
        lastNodes = 0
        lastDepth = 0
        return id
    }

    func clear() {
        lock.lock()
        token = nil
        session = nil
        turn = -1
        lastNodes = 0
        lastDepth = 0
        lock.unlock()
    }

    @discardableResult
    func record(_ trace: VeilGomokuUnifiedSearch.Trace, token candidate: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        guard token == candidate,
              (0...64).contains(trace.completedDepth),
              (0...500_000_000).contains(trace.nodes),
              trace.nodes >= lastNodes, trace.completedDepth >= lastDepth else {
            return false
        }
        lastNodes = trace.nodes
        lastDepth = trace.completedDepth
        return true
    }

    func snapshot(
        sessionID: String, turn: Int, isThinking: Bool
    ) -> VeilEclipseTracePolicy.LiveMetrics? {
        lock.lock()
        defer { lock.unlock() }
        guard isThinking, token != nil,
              self.session == sessionID, self.turn == turn,
              lastNodes > 0 || lastDepth > 0 else { return nil }
        return VeilEclipseTracePolicy.liveMetrics(from: .init(
            origin: .measuredEngine,
            completedDepth: lastDepth > 0 ? lastDepth : nil,
            visitedNodes: lastNodes > 0 ? lastNodes : nil,
            principalVariation: [], consideredIndices: [],
            explanation: nil
        ))
    }
}
