#include "eclipse_c_api.h"
#include "../src/eclipse_v9_research_ranker.hpp"
#include <algorithm>
#include <array>
#include <cstdint>
#include <iostream>
#include <memory>
#include <stdexcept>

#define REQUIRE(condition) do { \
    if (!(condition)) throw std::runtime_error("R21 V9 opt-in search failure: " #condition); \
} while (false)
using Engine = std::unique_ptr<EGEngine, decltype(&eg_destroy)>;

EGComputePolicyV2 policy() {
    EGComputePolicyV2 p{};
    p.size_bytes = sizeof(p);
    p.mode = EG_COMPUTE_MODE_BUDGETED;
    p.max_wall_time_ms = 1500;
    p.max_nodes = 100000;
    p.max_depth = 1;
    p.root_width = 1; // The ACTUAL V9 ordering must choose the root.
    p.reply_width = 1;
    p.continuation_width = 1;
    p.forced_line_depth = 0;
    p.candidate_radius = 2;
    return p;
}

int expectedTop(const std::array<std::uint8_t,225> &board, int selected) {
    int top = -1;
    int best = -1000000000;
    for (int index = 0; index < 225; ++index) {
        if (board[index]) continue;
        bool neighbor = false;
        for (int stone = 0; stone < 225; ++stone) {
            if (!board[stone]) continue;
            if (std::abs(index/15-stone/15) <= 2 &&
                std::abs(index%15-stone%15) <= 2) neighbor = true;
        }
        if (!neighbor) continue;
        const int score = selected == EG_RESEARCH_RANKER_LEGACY
            ? eclipse::trained_model::score(board,index,1)
            : eclipse::research_v9::score(board,index,1,selected);
        if (score > best) { top = index; best = score; }
    }
    REQUIRE(top >= 0);
    return top;
}

int main() {
    Engine engine(eg_create(),eg_destroy);
    REQUIRE(engine != nullptr);
    REQUIRE(eg_research_ranker_v3(nullptr) == -1);
    REQUIRE(eg_research_ranker_v3(engine.get()) == EG_RESEARCH_RANKER_LEGACY);
    REQUIRE(eg_select_research_ranker_v3(nullptr,EG_RESEARCH_RANKER_V9_ASTRA) == 0);
    REQUIRE(eg_select_research_ranker_v3(engine.get(),-1) == 0);
    REQUIRE(eg_select_research_ranker_v3(engine.get(),3) == 0);

    // Two legal moves give a quiet, non-forced root where a root-width-one
    // search result can be checked against the ACTUAL 314/160-tree score.
    REQUIRE(eg_play(engine.get(),112) == 1);
    REQUIRE(eg_play(engine.get(),97) == 1);
    std::array<std::uint8_t,225> board{};
    REQUIRE(eg_copy_board(engine.get(),board.data(),225) == 225);

    const auto cfg=policy();
    for (int model : {EG_RESEARCH_RANKER_LEGACY,
                      EG_RESEARCH_RANKER_V9_ASTRA,
                      EG_RESEARCH_RANKER_V9_SOL}) {
        REQUIRE(eg_select_research_ranker_v3(engine.get(),model) == 1);
        REQUIRE(eg_research_ranker_v3(engine.get()) == model);
        EGComputeRunV2 actual{};
        actual.size_bytes = sizeof(actual);
        REQUIRE(eg_analyze_compute_policy_v2(engine.get(),&cfg,
                nullptr,0,nullptr,0,&actual) == 1);
        const int expected=expectedTop(board,model);
        REQUIRE(actual.search.move == expected);
        REQUIRE(actual.search.completed_depth == 1);
        REQUIRE(actual.applied_policy.root_width == 1);
        std::array<std::uint8_t,225> after{};
        REQUIRE(eg_copy_board(engine.get(),after.data(),225) == 225);
        REQUIRE(after == board);
    }
    // Intentionally no fake product attestation: an opt-in research model is
    // NOT the production active checkpoint, even after the V2 search ran.
    char sha[65]{};
    REQUIRE(eg_active_trained_checkpoint_sha256_v2(sha,65) == 0);
    eg_reset(engine.get());
    REQUIRE(eg_research_ranker_v3(engine.get()) == EG_RESEARCH_RANKER_LEGACY);
    REQUIRE(eg_ply_count(engine.get()) == 0);
    std::cout << "R21 V9 research rankers ACTUALLY routed into C++ V2 search; "
                 "production attestation stays disabled\n";
}
