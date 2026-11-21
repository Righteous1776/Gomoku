#pragma once
#include <algorithm>
#include <array>
#include <cstdint>
#include <cstdlib>

namespace eclipse {

// An independently testable *heuristic* stopping rule, not a forced-win proof.
// Only consulted between FULLY COMPLETED iterative-deepening rounds in the
// trainer-controlled ADAPTIVE mode. It never starts/ends an incomplete depth.
// Parity-aware score comparison avoids confusing normal odd/even horizon
// oscillation with an unstable choice.
class AdaptiveConvergence {
public:
    struct Evidence {
        int completed_depth = 0;
        int best_move = -1;
        int best_score = 0;
        int runner_up_score = 0;
        bool tactical_risk = true;
    };

    // Quiet positions may end early ONLY when the same root wins at least
    // four consecutive completed depths (including both depth parities).
    // A positive gap against the second-best legal candidate is required
    // in each round; no confidence or winning probability is inferred.
    bool observe(const Evidence &e) {
        const bool consecutive = e.completed_depth == previous_depth_ + 1;
        const bool same_move = consecutive && e.best_move == previous_best_;
        const bool valid = e.completed_depth > 0 &&
            e.best_move >= 0 && e.best_move < 225 &&
            !e.tactical_risk &&
            e.best_score < 5'000'000 && e.best_score > -5'000'000 &&
            e.runner_up_score > -5'000'000 &&
            e.runner_up_score < e.best_score;
        const std::int64_t gap = static_cast<std::int64_t>(e.best_score) -
            e.runner_up_score;
        // A large score margin is necessary but NEVER sufficient evidence.
        const std::int64_t margin = std::max<std::int64_t>(
            650, std::llabs(static_cast<std::int64_t>(e.best_score)) / 5);
        const bool separated = valid && gap >= margin;
        const int parity = e.completed_depth % 2;
        bool parity_stable = true;
        if (have_parity_[parity] && consecutive) {
            const auto difference = std::llabs(
                static_cast<std::int64_t>(e.best_score) - parity_score_[parity]);
            const auto allowed = std::max<std::int64_t>(
                900, std::llabs(static_cast<std::int64_t>(e.best_score)) / 3);
            parity_stable = difference <= allowed;
        }
        stable_ = (same_move && separated && parity_stable)
            ? std::min(stable_ + 1, 4)
            : (separated ? 1 : 0);
        if (!valid || !consecutive) {
            have_parity_.fill(false);
        }
        have_parity_[parity] = separated;
        parity_score_[parity] = e.best_score;
        previous_depth_ = e.completed_depth;
        previous_best_ = e.best_move;
        return e.completed_depth >= 5 && stable_ >= 4 &&
            have_parity_[0] && have_parity_[1];
    }

private:
    int previous_depth_ = 0;
    int previous_best_ = -1;
    int stable_ = 0;
    std::array<bool, 2> have_parity_{};
    std::array<int, 2> parity_score_{};
};
} // namespace eclipse
