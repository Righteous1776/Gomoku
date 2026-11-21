#pragma once
// R21: opt-in, RESEARCH-ONLY, real V9 LightGBM C++ tree scorers.
// This code is not a production-model activation or a checkpoint identity
// attestation. Never return the source manifest SHA as "loaded" without
// demonstrating actual R19 production model installation.
#include "eclipse_trained_ordering.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <limits>

namespace eclipse::research_v9 {
struct Node {
    int feature;
    double threshold;
    int left;
    int right;
    double value;
};
// Use the REAL V9 exported forest coefficients from PR #45 in-place.
// Do not copy or commit additional private training data.
#include "../../Training/Handoffs/V9/source/research_engine/astra_new.inc"
#include "../../Training/Handoffs/V9/source/research_engine/sol_new.inc"

static_assert(std::size(astra_new::roots) == 314,
              "V9 Astra tree count changed");
static_assert(std::size(sol_new::roots) == 160,
              "V9 Sol tree count changed");
static_assert(std::size(astra_new::nodes) == 11250,
              "V9 Astra node count changed");
static_assert(std::size(sol_new::nodes) == 4126,
              "V9 Sol node count changed");

template <std::size_t N, std::size_t T>
inline double raw_forest(const Node (&nodes)[N], const int (&roots)[T],
                         const std::array<double,26> &features) {
    double value = 0.0;
    for (const int root : roots) {
        int index = root;
        // The exported arrays have only internal reference indices;
        // preserve fail-closed semantics if a corrupt export slips through.
        for (std::size_t visited = 0; visited <= N; ++visited) {
            if (index < 0 || static_cast<std::size_t>(index) >= N)
                return std::numeric_limits<double>::quiet_NaN();
            const auto &node = nodes[index];
            if (node.feature == -1) {
                value += node.value;
                break;
            }
            if (visited == N || node.feature < 0 || node.feature >= 26)
                return std::numeric_limits<double>::quiet_NaN();
            index = features[node.feature] <= node.threshold
                ? node.left : node.right;
        }
    }
    return value;
}

inline int score(const std::array<std::uint8_t, 225> &board,
                 int move, int side, int selected_ranker) {
    if (move < 0 || move >= 225 || board[move] != 0 ||
        (side != 1 && side != 2)) return 0;
    const auto f = trained_model::features(board, move, side);
    const double raw = selected_ranker == 1
        ? raw_forest(astra_new::nodes, astra_new::roots, f)
        : raw_forest(sol_new::nodes, sol_new::roots, f);
    if (!std::isfinite(raw)) return 0; // Invalid forest cannot dominate.
    // Preserve raw model ordering within int-scored search heuristics.
    return static_cast<int>(std::clamp(
        std::round(raw * 10000.0), -20000.0, 20000.0));
}
} // namespace eclipse::research_v9
