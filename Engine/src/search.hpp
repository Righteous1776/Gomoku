#pragma once
#include "board.hpp"
#include <array>
#include <atomic>
#include <chrono>
#include <cstdint>
#include <functional>
#include <unordered_map>
#include <vector>

namespace eclipse {
// Experimental search telemetry. NOT native Swift ECLIPSE strength parity.
// The enum's integer values are frozen by EG_SEARCH_DIAGNOSTICS_ABI_VERSION 1.
enum class SearchStopReason : int {
    complete = 0,
    forced_win = 1,
    forced_block = 2,
    only_move = 3,
    no_move = 4,
    time_limit = 5,
    cancelled = 6,
    // Adaptive V3 only: evidence-based, not mathematical certainty.
    adaptive_converged = 7,
    adaptive_effort_cap = 8,
    adaptive_next_depth_cost = 9
};

struct AdaptiveStopEvidence {
    int stable_rounds = 0;
    int score_gap = 0;      // native search score units; NOT win probability
    int complexity = 0;     // 0 clear / 1 uncertain / 2 tactical or ambiguous
    std::int64_t predicted_next_ms = 0; // measured node growth estimate
};

struct SearchResult {
    int move = -1;
    std::uint64_t nodes = 0;
    int completed_depth = 0;
    int elapsed_ms = 0;
    SearchStopReason reason = SearchStopReason::no_move;
    AdaptiveStopEvidence adaptive{};
};

// V1 bounded root policy from the unchanged Swift learning/formation layer.
// Restrictions cannot bypass mandatory immediate win / block checks.
struct RootPolicy {
    std::array<bool, kCells> allowed{};
    std::array<int, kCells> bonus{};
};

// Research V2: an independently trained model owns its full search geometry.
// Zero time/nodes = no imposed cutoff. Do not derive policy from old tiers.
struct ComputePolicy {
    std::int64_t max_wall_time_ms = 0;
    std::uint64_t max_nodes = 0;
    int max_depth = 1;
    int root_width = 1;
    int reply_width = 1;
    int continuation_width = 0;
    int forced_line_depth = 0;
    int candidate_radius = 2;
};

// Versioned opt-in termination policy. It never changes move ordering,
// tactical rules, trained weights or trainer-owned search geometry. The
// three time values are CEILINGS, not mandatory think durations. Adaptive
// decisions can finish earlier when conservative convergence is observed.
struct AdaptiveStopPolicy {
    int minimum_depth = 3;
    int stable_rounds = 3;
    int min_score_gap = 1800; // native static search units, uncalibrated
    std::int64_t clear_budget_ms = 1200;
    std::int64_t uncertain_budget_ms = 5000;
    std::int64_t complex_budget_ms = 20000;
};

// An explicit research-only selection; legacy remains the default for all
// previously supported callers and original Swift/C++ parity benchmarks.
enum class ResearchRanker : int { legacy = 0, v9_astra = 1, v9_sol = 2 };

class Search {
public:
    explicit Search(ResearchRanker ranker = ResearchRanker::legacy)
        : ranker_(ranker) {}
    // Optional per-search, read-only diagnostics sink. It must never choose a
    // move or change any search limit. Values describe completed iterations.
    using ProgressSink = std::function<void(std::uint64_t, int, int)>;
    using RankedRootsSink = std::function<void(const std::vector<int> &)>;
    using PVSink = std::function<void(int, const std::vector<int> &)>;
    SearchResult analyze(const Board &root, int milliseconds,
                         const RootPolicy *policy = nullptr,
                         const ComputePolicy *compute = nullptr,
                         const std::atomic<bool> *cancel = nullptr,
                         const ProgressSink &progress = {},
                         const RankedRootsSink &ranked_roots = {},
                         const PVSink &pv = {},
                         const AdaptiveStopPolicy *adaptive = nullptr);
    int best_move(const Board &root, int milliseconds);

private:
    ResearchRanker ranker_ = ResearchRanker::legacy;
    int move_rank(int index, int side) const;
    using Clock = std::chrono::steady_clock;
    static constexpr int kMate = 10'000'000;
    static constexpr int kInf = kMate + 100'000;
    struct Entry {
        int depth = 0;
        int score = 0;
        int best = -1;
        int flag = 0; // exact 0; lower 1; upper 2
    };
    std::array<std::uint8_t, kCells> cells_{};
    int free_ = kCells;
    std::uint64_t hash_ = 0;
    std::uint64_t nodes_ = 0;
    std::uint64_t node_cap_ = 80'000;
    bool timed_out_ = false;
    bool cancelled_ = false;
    const std::atomic<bool> *cancel_signal_ = nullptr;
    ProgressSink progress_{};
    int last_completed_depth_ = 0;
    int last_best_move_ = -1;
    std::uint64_t last_progress_nodes_ = 0;
    int candidate_radius_ = 2;
    int root_width_ = 18;
    int proof_width_ = 28;
    int reply_width_ = 14;
    int continuation_width_ = 14;
    int forced_line_depth_ = 5;
    int leaf_forced_blocks_ = 2;
    int max_depth_ = 9;
    std::array<bool, kCells> allowed_proof_root_{};
    Clock::time_point deadline_{};
    Clock::time_point proof_deadline_{};
    std::unordered_map<std::uint64_t, Entry> table_;

    static constexpr int other(int side) { return side == 1 ? 2 : 1; }
    static bool inside(int row, int col) {
        return row >= 0 && row < kSide && col >= 0 && col < kSide;
    }
    static const std::array<std::array<std::uint64_t, 3>, kCells> &zobrist();
    static const std::array<std::uint64_t, 3> &side_hash();
    void place(int index, int side);
    void unplace(int index, int side);
    bool five_at(int index, int side) const;
    bool winning_move(int index, int side) const;
    std::vector<int> neighbors(int radius = 2) const;
    std::vector<int> immediate_wins(int side, const std::vector<int> &candidates) const;
    int fork_count(int side) const;
    int pattern_priority(int index, int side) const;
    std::vector<int> ordered(const std::vector<int> &moves, int side,
                             int limit, int previous_best = -1) const;
    int static_value(int side) const;
    bool limit_reached();
    bool prove_four(int side, int remaining, bool restrict_root,
                    std::vector<int> &variation);
    int tactical_leaf(int side, int ply, int remaining_forced);
    int negamax(int side, int depth, int alpha, int beta, int last, int ply);
    // Build only a real principal-variation PREFIX: exact TT entries that
    // were stored by the finished search, never a hypothetical filler line.
    std::vector<int> extract_verified_pv_prefix(int first, int side,
                                                 int completed_depth);
};
}
