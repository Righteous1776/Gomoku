#include "eclipse_c_api.h"
#include <array>
#include <cstdint>
#include <cstring>
#include <iostream>
#include <memory>
#include <stdexcept>

#define REQUIRE(condition) do { \
    if (!(condition)) throw std::runtime_error("V9 synthetic unique-block regression: " #condition); \
} while (false)

using OwnedEngine = std::unique_ptr<EGEngine, decltype(&eg_destroy)>;

// Fully synthetic V9 research fixture, never an owner/player game.
// Black: [10,79,95,111], White: [4,19,34,49].
// Black must block at 64, even though Astra V9 research ranking preferred 63.
constexpr std::array<std::int32_t, 8> kHistory = {
    10, 4, 79, 19, 95, 34, 111, 49
};
constexpr int kOnlyBlock = 64;
constexpr int kMisranked = 63;

static EGComputePolicyV2 researchPolicy(bool astra) {
    EGComputePolicyV2 policy{};
    policy.size_bytes = sizeof(policy);
    policy.mode = EG_COMPUTE_MODE_BUDGETED;
    // Trainer's candidate safety ceilings; NOT production/default budgets.
    policy.max_wall_time_ms = astra ? 30000 : 8000;
    policy.max_nodes = astra ? 1200000 : 400000;
    policy.max_depth = astra ? 12 : 9;
    policy.root_width = astra ? 24 : 16;
    policy.reply_width = astra ? 16 : 10;
    policy.continuation_width = astra ? 8 : 6;
    policy.forced_line_depth = astra ? 8 : 6;
    policy.candidate_radius = astra ? 3 : 2;
    return policy;
}

int main() {
    REQUIRE(eg_compute_policy_abi_version() == 2);
    OwnedEngine engine(eg_create(), eg_destroy);
    REQUIRE(engine != nullptr);
    for (auto move : kHistory) REQUIRE(eg_play(engine.get(), move) == 1);
    REQUIRE(eg_status(engine.get()) == 0);
    REQUIRE(eg_to_move(engine.get()) == 1);
    REQUIRE(eg_ply_count(engine.get()) == 8);

    std::array<std::uint8_t, 225> expected{};
    std::int32_t to_move = 0, status = -1;
    REQUIRE(eg_rules_replay_v1(kHistory.data(), static_cast<int>(kHistory.size()),
        expected.data(), static_cast<int>(expected.size()), &to_move, &status) == 1);
    REQUIRE(to_move == 1 && status == 0);
    std::array<std::uint8_t, 225> before{};
    REQUIRE(eg_copy_board(engine.get(), before.data(), 225) == 225);
    REQUIRE(before == expected);
    REQUIRE(before[kOnlyBlock] == 0 && before[kMisranked] == 0);

    std::array<std::uint8_t, 225> allowed{};
    allowed.fill(1);
    std::array<std::int32_t, 225> bonuses{};
    bonuses[kMisranked] = 2000;
    bonuses[kOnlyBlock] = -2000;

    for (int family = 0; family != 2; ++family) {
        // R21 actually selects the C++ V9 tree forest used by the search,
        // rather than merely passing the Astra/Sol compute policy.
        const int ranker = family == 0 ? EG_RESEARCH_RANKER_V9_ASTRA
                                       : EG_RESEARCH_RANKER_V9_SOL;
        REQUIRE(eg_select_research_ranker_v3(engine.get(), ranker) == 1);
        REQUIRE(eg_research_ranker_v3(engine.get()) == ranker);
        const auto policy = researchPolicy(family == 0);
        EGComputeRunV2 result{};
        result.size_bytes = sizeof(result);
        REQUIRE(eg_analyze_compute_policy_v2(engine.get(), &policy,
            allowed.data(), 225, bonuses.data(), 225, &result) == 1);
        REQUIRE(result.search.move == kOnlyBlock);
        REQUIRE(result.search.reason == EG_SEARCH_REASON_FORCED_BLOCK);
        REQUIRE(result.search.completed_depth == 0);
        REQUIRE(std::memcmp(&policy, &result.applied_policy, sizeof(policy)) == 0);
        REQUIRE(eg_ply_count(engine.get()) == 8);
        std::array<std::uint8_t, 225> after{};
        REQUIRE(eg_copy_board(engine.get(), after.data(), 225) == 225);
        REQUIRE(after == before);

        // A root policy excluding the ONLY block must fail closed.
        allowed[kOnlyBlock] = 0;
        const auto original = result;
        REQUIRE(eg_analyze_compute_policy_v2(engine.get(), &policy,
            allowed.data(), 225, bonuses.data(), 225, &result) == 0);
        REQUIRE(std::memcmp(&original, &result, sizeof(result)) == 0);
        allowed[kOnlyBlock] = 1;
    }

    std::cout << "V9 synthetic forced-block R19 C++ V2 gate PASSED; "
                 "research policies only, no 2.0 checkpoint loaded assertion\n";
}
