#include "../src/eclipse_trained_ordering.hpp"
#include <algorithm>
#include <array>
#include <cmath>
#include <cstddef>
#include <iostream>
#include <stdexcept>
#include <utility>
#include <vector>

// These are the *real staged* V9 26-feature static LightGBM trees.
// This test exercises C++ score decoding only, NOT the production search
// path or the still-unverified R19 loaded-checkpoint attestation.
struct Node {
    int feature;
    double threshold;
    int left, right;
    double value;
};
#include "../../Training/Handoffs/V9/source/research_engine/astra_new.inc"
#include "../../Training/Handoffs/V9/source/research_engine/sol_new.inc"

#define REQUIRE(condition) do { \
    if (!(condition)) throw std::runtime_error("V9 research forest parity: " #condition); \
} while (false)

template <std::size_t Nodes, std::size_t Trees>
double rawForest(const Node (&nodes)[Nodes], const int (&roots)[Trees],
                 const std::array<double, 26> &features) {
    double score = 0;
    for (int root : roots) {
        int position = root;
        for (std::size_t guard = 0; ; ++guard) {
            REQUIRE(position >= 0 && static_cast<std::size_t>(position) < Nodes);
            REQUIRE(guard <= Nodes);
            const Node &node = nodes[position];
            if (node.feature == -1) {
                score += node.value;
                break;
            }
            REQUIRE(node.feature >= 0 && node.feature < 26);
            position = features[node.feature] <= node.threshold
                ? node.left : node.right;
        }
    }
    REQUIRE(std::isfinite(score));
    return score;
}

template <std::size_t Nodes, std::size_t Trees>
void verifyModel(const Node (&nodes)[Nodes], const int (&roots)[Trees],
                 const std::array<std::uint8_t, 225> &board, int expectedTrees) {
    REQUIRE(static_cast<int>(Trees) == expectedTrees);
    std::vector<std::pair<double, int>> order;
    for (int move = 0; move < 225; ++move) {
        if (board[move]) continue;
        const auto features = eclipse::trained_model::features(board, move, 1);
        order.emplace_back(rawForest(nodes, roots, features), move);
    }
    std::sort(order.begin(), order.end(), [](const auto &a, const auto &b) {
        return a.first == b.first ? a.second < b.second : a.first > b.first;
    });
    // This is an EXPECTED RESEARCH REGRESSION, not a model-success claim.
    // V9 Astra / V9 Sol raw scores prefer 63, with mandatory defense 64 third.
    // The production C++ V2 search test independently requires a forced 64.
    REQUIRE(!order.empty() && order.front().second == 63);
    const auto it = std::find_if(order.begin(), order.end(), [](const auto &x) {
        return x.second == 64;
    });
    REQUIRE(it != order.end());
    REQUIRE(std::distance(order.begin(), it) == 2);
}

int main() {
    std::array<std::uint8_t, 225> board{};
    for (int move : {10, 79, 95, 111}) board[move] = 1;
    for (int move : {4, 19, 34, 49}) board[move] = 2;
    verifyModel(astra_new::nodes, astra_new::roots, board, 314);
    verifyModel(sol_new::nodes, sol_new::roots, board, 160);
    std::cout << "V9 actual 314/160-tree C++ ranker reproduction PASSED; "
                 "both still BLOCKED for production promotion\n";
}
