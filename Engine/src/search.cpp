#include "search.hpp"
#include "eclipse_trained_ordering.hpp"
#include "eclipse_v9_research_ranker.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <limits>
#include <numeric>
#include <utility>

namespace eclipse {
namespace {
constexpr int kAxes[4][2] = {{1, 0}, {0, 1}, {1, 1}, {1, -1}};
std::uint64_t splitmix(std::uint64_t &state) {
    std::uint64_t z = (state += UINT64_C(0x9e3779b97f4a7c15));
    z = (z ^ (z >> 30)) * UINT64_C(0xbf58476d1ce4e5b9);
    z = (z ^ (z >> 27)) * UINT64_C(0x94d049bb133111eb);
    return z ^ (z >> 31);
}
} // namespace

const std::array<std::array<std::uint64_t, 3>, kCells> &Search::zobrist() {
    static const auto keys = [] {
        std::array<std::array<std::uint64_t, 3>, kCells> result{};
        std::uint64_t seed = UINT64_C(0xD40C0F0A2026);
        for (auto &row : result) {
            row[1] = splitmix(seed);
            row[2] = splitmix(seed);
        }
        return result;
    }();
    return keys;
}
const std::array<std::uint64_t, 3> &Search::side_hash() {
    static const auto keys = [] {
        std::array<std::uint64_t, 3> result{};
        std::uint64_t seed = UINT64_C(0xB0611A27);
        result[1] = splitmix(seed);
        result[2] = splitmix(seed);
        return result;
    }();
    return keys;
}

void Search::place(int index, int side) {
    cells_[index] = static_cast<std::uint8_t>(side);
    hash_ ^= zobrist()[index][side];
    --free_;
}
void Search::unplace(int index, int side) {
    cells_[index] = 0;
    hash_ ^= zobrist()[index][side];
    ++free_;
}
bool Search::five_at(int index, int side) const {
    if (index < 0 || index >= kCells || cells_[index] != side) return false;
    const int row = index / kSide, col = index % kSide;
    for (const auto &axis : kAxes) {
        int count = 1;
        for (int sign : {-1, 1}) {
            int r = row + sign * axis[0], c = col + sign * axis[1];
            while (inside(r, c) && cells_[r * kSide + c] == side) {
                ++count;
                r += sign * axis[0];
                c += sign * axis[1];
            }
        }
        if (count >= 5) return true;
    }
    return false;
}
bool Search::winning_move(int index, int side) const {
    if (index < 0 || index >= kCells || cells_[index] != 0) return false;
    const int row = index / kSide, col = index % kSide;
    for (const auto &axis : kAxes) {
        int count = 1;
        for (int sign : {-1, 1}) {
            int r = row + sign * axis[0], c = col + sign * axis[1];
            while (inside(r, c) && cells_[r * kSide + c] == side) {
                ++count;
                r += sign * axis[0];
                c += sign * axis[1];
            }
        }
        if (count >= 5) return true;
    }
    return false;
}

std::vector<int> Search::neighbors(int radius) const {
    if (free_ == kCells) return {112};
    radius = std::clamp(radius, 1, kSide - 1);
    std::array<bool, kCells> visited{};
    for (int i = 0; i < kCells; ++i) {
        if (!cells_[i]) continue;
        const int r = i / kSide, c = i % kSide;
        for (int dr = -radius; dr <= radius; ++dr)
            for (int dc = -radius; dc <= radius; ++dc) {
                if (!inside(r + dr, c + dc)) continue;
                const int next = (r + dr) * kSide + c + dc;
                if (!cells_[next]) visited[next] = true;
            }
    }
    std::vector<int> out;
    out.reserve(kCells);
    for (int i = 0; i < kCells; ++i)
        if (visited[i]) out.push_back(i);
    return out;
}

std::vector<int> Search::immediate_wins(
    int side, const std::vector<int> &candidates) const {
    std::vector<int> wins;
    for (int i : candidates)
        if (winning_move(i, side)) wins.push_back(i);
    return wins;
}

// Exact counterpart of Swift GomokuCounterForkR4.forkCellCount.
// Duplicate overlapping five-windows do NOT create fake forks.
int Search::fork_count(int side) const {
    std::array<std::int16_t, kCells> first_reply{};
    first_reply.fill(-1);
    std::array<bool, kCells> forked{};
    int count = 0;
    for (int r = 0; r < kSide; ++r)
        for (int c = 0; c < kSide; ++c)
            for (const auto &axis : kAxes) {
                if (!inside(r + 4 * axis[0], c + 4 * axis[1])) continue;
                int own = 0, a = -1, b = -1;
                bool blocked = false;
                for (int k = 0; k < 5; ++k) {
                    const int i = (r + k * axis[0]) * kSide + c + k * axis[1];
                    if (cells_[i] == side) ++own;
                    else if (cells_[i] == 0) {
                        if (a == -1) a = i;
                        else b = i;
                    } else { blocked = true; break; }
                }
                if (blocked || own != 3 || a < 0 || b < 0) continue;
                for (const auto pair : {std::pair<int,int>{a,b}, {b,a}}) {
                    const int candidate = pair.first, completion = pair.second;
                    if (first_reply[candidate] < 0)
                        first_reply[candidate] = static_cast<std::int16_t>(completion);
                    else if (first_reply[candidate] != completion && !forked[candidate]) {
                        forked[candidate] = true;
                        ++count;
                    }
                }
            }
    return count;
}

int Search::pattern_priority(int index, int side) const {
    const int row = index / kSide, col = index % kSide;
    int total = 0;
    for (const auto &axis : kAxes)
        for (int sign : {-1, 1})
            for (int dist = 1; dist <= 2; ++dist) {
                const int r = row + sign * dist * axis[0];
                const int c = col + sign * dist * axis[1];
                if (!inside(r, c)) continue;
                const auto v = cells_[r * kSide + c];
                if (v == side) total += dist == 1 ? 18 : 5;
                else if (v == other(side)) total += dist == 1 ? 12 : 3;
            }
    return total * 8 + kSide - std::abs(row - 7) - std::abs(col - 7);
}
int Search::move_rank(int index, int side) const {
    switch (ranker_) {
    case ResearchRanker::v9_astra:
        return research_v9::score(cells_, index, side, 1);
    case ResearchRanker::v9_sol:
        return research_v9::score(cells_, index, side, 2);
    case ResearchRanker::legacy:
    default:
        return trained_model::score(cells_, index, side);
    }
}

std::vector<int> Search::ordered(const std::vector<int> &moves,
                                  int side, int limit, int preferred) const {
    std::vector<std::pair<int,int>> sorted;
    sorted.reserve(moves.size());
    for (int i : moves) sorted.emplace_back(i, move_rank(i, side));
    std::sort(sorted.begin(), sorted.end(), [preferred](const auto &a, const auto &b) {
        if (a.first == b.first) return false; // strict weak ordering, including self
        if (a.first == preferred) return true;
        if (b.first == preferred) return false;
        if (a.second == b.second) return a.first < b.first;
        return a.second > b.second;
    });
    std::vector<int> out;
    for (int i = 0; i < static_cast<int>(sorted.size()) && i < limit; ++i)
        out.push_back(sorted[i].first);
    return out;
}

// Same five-window weights as VeilGomokuUnifiedSearch.staticValue.
// TrainedOrdering remains a separate, not-yet-ported layer.
int Search::static_value(int side) const {
    constexpr int weight[6] = {0, 2, 28, 900, 45000, 900000};
    int black = 0, white = 0;
    for (const auto &axis : kAxes)
        for (int r = 0; r < kSide; ++r)
            for (int c = 0; c < kSide; ++c) {
                if (!inside(r + 4 * axis[0], c + 4 * axis[1])) continue;
                int b = 0, w = 0;
                for (int k = 0; k < 5; ++k) {
                    const auto v = cells_[(r + k * axis[0]) * kSide + c + k * axis[1]];
                    b += (v == 1);
                    w += (v == 2);
                }
                if (!w) black += weight[b];
                if (!b) white += weight[w];
            }
    const int value = side == 1 ? black - white : white - black;
    return std::clamp(value, -kMate / 4, kMate / 4);
}
bool Search::limit_reached() {
    // Only sample nodes occasionally; never synchronously call SwiftUI.
    if (progress_ && (nodes_ & 2047ULL) == 0)
        progress_(nodes_, last_completed_depth_, last_best_move_);
    if (cancel_signal_ && cancel_signal_->load(std::memory_order_relaxed)) {
        cancelled_ = true;
        timed_out_ = true;
        return true;
    }
    if (timed_out_) return true;
    if (nodes_ >= node_cap_ || Clock::now() >= deadline_)
        timed_out_ = true;
    return timed_out_;
}

// Conservative Swift-style verified forcing-four continuation.
// No heuristic line can be labeled a mathematical forced win.
bool Search::prove_four(int side, int remaining, bool restrict_root,
                        std::vector<int> &pv) {
    ++nodes_;
    if (remaining <= 0 || Clock::now() >= proof_deadline_ || limit_reached())
        return false;
    const auto candidates = neighbors(candidate_radius_);
    if (!immediate_wins(other(side), candidates).empty()) return false;
    const auto direct = immediate_wins(side, candidates);
    if (!direct.empty()) {
        if (!restrict_root || allowed_proof_root_[direct.front()]) {
            pv = {direct.front()};
            return true;
        }
    }
    for (const int move : ordered(candidates, side, proof_width_)) {
        if (restrict_root && !allowed_proof_root_[move]) continue;
        if (Clock::now() >= proof_deadline_ || limit_reached()) return false;
        place(move, side);
        const auto after = neighbors(candidate_radius_);
        const auto ours = immediate_wins(side, after);
        const auto theirs = immediate_wins(other(side), after);
        if (theirs.empty() && ours.size() >= 2) {
            pv = {move, ours.front()};
            unplace(move, side);
            return true;
        }
        if (theirs.empty() && ours.size() == 1 && remaining > 1) {
            const int forced = ours.front();
            place(forced, other(side));
            std::vector<int> tail;
            const bool proven = prove_four(side, remaining - 1, false, tail);
            unplace(forced, other(side));
            if (proven) {
                pv = {move, forced};
                pv.insert(pv.end(), tail.begin(), tail.end());
                unplace(move, side);
                return true;
            }
        }
        unplace(move, side);
    }
    return false;
}

// Swift R12 leaf extension is explicitly optional upstream; this bounded
// implementation never declares a quiet position to be a proven win.
int Search::tactical_leaf(int side, int ply, int remaining_forced) {
    ++nodes_;
    if (limit_reached()) return 0;
    const auto moves = neighbors(candidate_radius_);
    if (!immediate_wins(side, moves).empty()) return kMate - ply - 1;
    const auto threats = immediate_wins(other(side), moves);
    if (threats.size() >= 2) return -kMate + ply + 2;
    if (threats.size() == 1) {
        const int forced = threats.front();
        place(forced, side);
        const int value = remaining_forced > 1
            ? -tactical_leaf(other(side), ply + 1, remaining_forced - 1)
            : -static_value(other(side));
        unplace(forced, side);
        return value;
    }
    return static_value(side);
}

int Search::negamax(int side, int depth, int alpha, int beta,
                    int last, int ply) {
    ++nodes_;
    if (limit_reached()) return 0;
    if (last >= 0 && five_at(last, other(side))) return -kMate + ply;
    if (!free_) return 0;
    if (depth <= 0) return leaf_forced_blocks_ > 0
        ? tactical_leaf(side, ply, leaf_forced_blocks_) : static_value(side);
    const std::uint64_t key = hash_ ^ side_hash()[side];
    const int old_alpha = alpha;
    const auto found = table_.find(key);
    if (found != table_.end() && found->second.depth >= depth) {
        const Entry &entry = found->second;
        if (entry.flag == 0) return entry.score;
        if (entry.flag == 1 && entry.score >= beta) return entry.score;
        if (entry.flag == 2 && entry.score <= alpha) return entry.score;
    }
    auto moves = neighbors(candidate_radius_);
    if (!immediate_wins(side, moves).empty()) return kMate - ply - 1;
    const auto blocks = immediate_wins(other(side), moves);
    if (blocks.size() > 1) return -kMate + ply + 2;
    if (blocks.size() == 1) moves = {blocks.front()};
    const int active_width = ply <= 1 || continuation_width_ == 0
        ? reply_width_ : continuation_width_;
    moves = ordered(moves, side, active_width,
                    found != table_.end() ? found->second.best : -1);
    int best = -kInf, best_move = -1, lower = alpha;
    bool first = true;
    for (const int move : moves) {
        place(move, side);
        int score = 0;
        if (first) {
            score = -negamax(other(side), depth - 1, -beta, -lower, move, ply + 1);
        } else {
            score = -negamax(other(side), depth - 1, -lower - 1, -lower, move, ply + 1);
            if (!timed_out_ && score > lower && score < beta)
                score = -negamax(other(side), depth - 1, -beta, -lower, move, ply + 1);
        }
        unplace(move, side);
        if (timed_out_) return 0;
        if (score > best) { best = score; best_move = move; }
        lower = std::max(lower, score);
        if (lower >= beta) break;
        first = false;
    }
    if (best_move >= 0 && std::abs(best) < kMate / 2) {
        if (table_.size() > 50'000) table_.clear();
        const int flag = best <= old_alpha ? 2 : best >= beta ? 1 : 0;
        table_[key] = Entry{depth, best, best_move, flag};
    }
    return best == -kInf ? static_value(side) : best;
}

SearchResult Search::analyze(const Board &root, int milliseconds,
                             const RootPolicy *policy,
                             const ComputePolicy *compute,
                             const std::atomic<bool> *cancel,
                             const ProgressSink &progress) {
    const auto started = Clock::now();
    nodes_ = 0;
    timed_out_ = false;
    cancelled_ = false;
    cancel_signal_ = cancel;
    progress_ = progress;
    last_completed_depth_ = 0;
    last_best_move_ = -1;
    if (progress_) progress_(0, 0, -1);
    candidate_radius_ = compute ? compute->candidate_radius : 2;
    root_width_ = compute ? compute->root_width : 18;
    reply_width_ = compute ? compute->reply_width : 14;
    continuation_width_ = compute ? compute->continuation_width : 14;
    proof_width_ = compute ? compute->root_width : 28;
    forced_line_depth_ = compute ? compute->forced_line_depth : 5;
    leaf_forced_blocks_ = compute ? compute->forced_line_depth : 2;
    table_.clear();
    allowed_proof_root_.fill(false);
    // Research API convention: 0 means no imposed wall-clock deadline.
    // Positive time budgets come from the training agent or experiment
    // caller. Do not silently clamp a requested 30s / 90s to 20s.
    const std::int64_t max_ms = compute ? compute->max_wall_time_ms
        : static_cast<std::int64_t>(std::max(0, milliseconds));
    const bool open_ended = max_ms == 0;
    const auto until_max = std::chrono::duration_cast<std::chrono::milliseconds>(
        Clock::time_point::max() - started).count();
    // Only representable steady_clock capacity limits the clock arithmetic,
    // not a product-defined 20s/5.7s cap.
    deadline_ = open_ended || max_ms >= until_max
        ? Clock::time_point::max()
        : started + std::chrono::milliseconds(max_ms);
    // Trainer's own policy uses the full allocated time for proof if needed;
    // legacy benchmark retains its historical 30% proof reservation.
    proof_deadline_ = compute ? deadline_ : open_ended
        ? Clock::time_point::max()
        : started + std::chrono::milliseconds(max_ms * 3 / 10);
    node_cap_ = compute && compute->max_nodes > 0
        ? compute->max_nodes : std::numeric_limits<std::uint64_t>::max();
    max_depth_ = compute ? compute->max_depth
        : open_ended || max_ms >= 2500 ? 9 : max_ms >= 900 ? 8 : 6;
    cells_ = root.cells;
    free_ = static_cast<int>(std::count(cells_.begin(), cells_.end(), 0));
    hash_ = 0;
    for (int i = 0; i < kCells; ++i)
        if (cells_[i]) hash_ ^= zobrist()[i][cells_[i]];
    auto finish = [&](int move, SearchStopReason reason, int depth) {
        SearchResult result;
        result.move = move;
        result.reason = reason;
        result.completed_depth = depth;
        result.nodes = nodes_;
        result.elapsed_ms = static_cast<int>(
            std::chrono::duration_cast<std::chrono::milliseconds>(
                Clock::now() - started).count());
        if (progress_) progress_(nodes_, depth, move);
        return result;
    };
    if (root.outcome != 0 || free_ == 0)
        return finish(-1, SearchStopReason::no_move, 0);
    const auto all_roots = neighbors(candidate_radius_);
    std::vector<int> roots;
    for (const int move : all_roots)
        if (!policy || policy->allowed[move]) roots.push_back(move);
    if (roots.empty()) return finish(-1, SearchStopReason::no_move, 0);
    if (roots.size() == 1 && all_roots.size() == 1)
        return finish(roots.front(), SearchStopReason::only_move, 0);
    const int side = root.turn;
    const auto all_wins = immediate_wins(side, all_roots);
    if (!all_wins.empty()) {
        const auto wins = immediate_wins(side, roots);
        if (wins.empty()) return finish(-1, SearchStopReason::no_move, 0);
        return finish(wins.front(), SearchStopReason::forced_win, 0);
    }
    const auto all_blocks = immediate_wins(other(side), all_roots);
    if (!all_blocks.empty()) {
        const auto blocks = immediate_wins(other(side), roots);
        if (blocks.empty()) return finish(-1, SearchStopReason::no_move, 0);
        return finish(blocks.front(), SearchStopReason::forced_block, 0);
    }
    // Original Swift normalized root ranking is additive only after verified
    // mandatory tactics, and never changes a mate / forced-loss certificate.
    auto root_ordered = [&](const std::vector<int> &candidates, int limit) {
        if (!policy) return ordered(candidates, side, limit);
        std::vector<std::pair<int,int>> scored;
        for (int move : candidates) {
            const int preference = std::clamp(policy->bonus[move], -2000, 2000);
            scored.push_back({move, move_rank(move, side) + preference});
        }
        std::sort(scored.begin(), scored.end(), [](const auto &a, const auto &b) {
            return a.second == b.second ? a.first < b.first : a.second > b.second;
        });
        std::vector<int> result;
        for (int i = 0; i < static_cast<int>(scored.size()) && i < limit; ++i)
            result.push_back(scored[i].first);
        return result;
    };

    // Exact two-different-five-completions: an unanswerable one-move fork
    // when the opponent has no immediate win after our hypothetical move.
    for (const int move : roots) {
        if (limit_reached()) break;
        place(move, side);
        const auto next = neighbors(candidate_radius_);
        const auto finishers = immediate_wins(side, next);
        const auto enemy = immediate_wins(other(side), next);
        unplace(move, side);
        if (finishers.size() >= 2 && enemy.empty())
            return finish(move, SearchStopReason::forced_win, 0);
        if (limit_reached()) break;
    }

    // Rule-certified opponent fork filter, before trained/heuristic ordering.
    // If every move loses the fork gate, keep ALL candidates rather than
    // fabricating a losing-move proof or dropping counterattacks.
    std::vector<int> eligible;
    std::vector<std::pair<int,int>> risks;
    bool finished_fork_audit = true;
    for (const int move : roots) {
        if (limit_reached()) { finished_fork_audit = false; break; }
        place(move, side);
        const int forks = fork_count(other(side));
        unplace(move, side);
        if (forks == 0) eligible.push_back(move);
        risks.push_back({move, forks});
    }
    if (finished_fork_audit) {
        if (eligible.empty()) {
            std::stable_sort(risks.begin(), risks.end(),
                 [](const auto &a, const auto &b) {
                     return a.second < b.second;
                 });
            for (const auto &risk : risks) eligible.push_back(risk.first);
        }
    } else {
        // Partial safety classification cannot silently omit unchecked roots.
        eligible = roots;
    }
    const auto fallbacks = root_ordered(eligible, static_cast<int>(eligible.size()));
    if (fallbacks.empty()) return finish(-1, SearchStopReason::no_move, 0);
    int incumbent = fallbacks.front(), completed = 0;
    if (cancelled_) return finish(incumbent, SearchStopReason::cancelled, 0);
    if (Clock::now() >= deadline_)
        return finish(incumbent, SearchStopReason::time_limit, 0);
    for (const int i : eligible) allowed_proof_root_[i] = true;
    if (forced_line_depth_ > 0 && (open_ended || max_ms >= 40)) {
        std::vector<int> pv;
        if (prove_four(side, forced_line_depth_, true, pv) && !pv.empty())
            return finish(pv.front(), SearchStopReason::forced_win,
                          static_cast<int>(pv.size()));
    }
    if (cancelled_) return finish(incumbent, SearchStopReason::cancelled, 0);
    timed_out_ = false; // A missed proof isn't necessarily a failed game search.
    if (cancelled_) return finish(incumbent, SearchStopReason::cancelled, 0);
    if (Clock::now() >= deadline_)
        return finish(incumbent, SearchStopReason::time_limit, 0);
    const auto ranked = root_ordered(eligible,
                                     std::min(root_width_, static_cast<int>(eligible.size())));
    for (int depth = 1; depth <= max_depth_; ++depth) {
        int round_best = -1, round_score = -kInf;
        for (int move : ranked) {
            ++nodes_;
            if (limit_reached()) break;
            place(move, side);
            int score = -negamax(other(side), depth - 1, -kInf, kInf, move, 1);
            unplace(move, side);
            if (timed_out_) break;
            if (policy && std::abs(score) < kMate / 2)
                score += std::clamp(policy->bonus[move], -2000, 2000);
            if (score > round_score) {
                round_score = score;
                round_best = move;
            }
        }
        if (timed_out_) break;
        if (round_best >= 0) {
            incumbent = round_best;
            completed = depth;
            last_completed_depth_ = completed;
            last_best_move_ = incumbent;
            if (progress_) progress_(nodes_, completed, incumbent);
            if (round_score >= kMate / 2) break;
        }
    }
    return finish(incumbent, cancelled_ ? SearchStopReason::cancelled
        : timed_out_ ? SearchStopReason::time_limit
                     : SearchStopReason::complete, completed);
}
int Search::best_move(const Board &root, int milliseconds) {
    return analyze(root, milliseconds).move;
}
} // namespace eclipse
