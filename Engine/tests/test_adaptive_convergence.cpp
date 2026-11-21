#include "adaptive_convergence.hpp"
#include "eclipse_c_api.h"
#include <array>
#include <cstdint>
#include <iostream>
#include <memory>
#include <stdexcept>

#define CHECK(x) do { if (!(x)) throw std::runtime_error("adaptive: " #x); } while(false)
using Owner = std::unique_ptr<EGEngine, decltype(&eg_destroy)>;

static EGComputePolicyV2 configured(int mode) {
    EGComputePolicyV2 p{};
    p.size_bytes = sizeof(p);
    p.mode = mode;
    p.max_wall_time_ms = mode == EG_COMPUTE_MODE_ADAPTIVE ? 0 : 5000;
    p.max_nodes = 0;
    p.max_depth = 6;
    p.root_width = 4;
    p.reply_width = 3;
    p.continuation_width = 2;
    p.forced_line_depth = 0;
    p.candidate_radius = 2;
    return p;
}
static EGComputeRunV2 run(EGEngine *e, EGComputePolicyV2 p) {
    EGComputeRunV2 result{};
    result.size_bytes = sizeof(result);
    CHECK(eg_analyze_compute_policy_v2(e, &p, nullptr, 0, nullptr, 0, &result) == 1);
    CHECK(result.search.move >= 0 && result.search.move < 225);
    CHECK(result.search.completed_depth >= 0);
    CHECK(result.applied_policy.mode == p.mode);
    return result;
}
int main() {
    {
        eclipse::AdaptiveConvergence tracker;
        // Stable, separated roots with normally oscillating odd/even scores
        // are a valid reason to skip further QUIET depth extensions.
        for (int d=1; d<=5; ++d) {
            const int score = d % 2 ? 1250 + d * 5 : 1170 + d * 5;
            const auto stable = tracker.observe({d, 112, score, 100, false});
            CHECK(stable == (d == 5));
        }
    }
    {
        eclipse::AdaptiveConvergence tracker;
        // Stable root move alone is NEVER sufficient when tactical danger
        // or the runner-up is close.
        for (int d=1; d<=12; ++d)
            CHECK(!tracker.observe({d, 112, 1500, 1400, false}));
    }
    {
        eclipse::AdaptiveConvergence tracker;
        for (int d=1; d<=12; ++d)
            CHECK(!tracker.observe({d, 112, 1550, 50, true}));
    }
    {
        eclipse::AdaptiveConvergence tracker;
        for (int d=1; d<=12; ++d)
            CHECK(!tracker.observe({d, d % 2 ? 112 : 113,
                                   1550, 50, false}));
    }
    {
        eclipse::AdaptiveConvergence tracker;
        for (int d=1; d<=12; ++d)
            CHECK(!tracker.observe({d, 112, 5'000'100, 50, false}));
    }

    Owner e(eg_create(), eg_destroy);
    CHECK(e != nullptr);
    // Real engine, real 15x15 turn replay, no invented search stats.
    CHECK(eg_play(e.get(), 112) == 1);
    CHECK(eg_play(e.get(), 97) == 1);
    auto adaptive = configured(EG_COMPUTE_MODE_ADAPTIVE);
    auto budgeted = configured(EG_COMPUTE_MODE_BUDGETED);
    const auto a = run(e.get(), adaptive);
    const auto b = run(e.get(), budgeted);
    // A heuristic plateau MAY end earlier. A budgeted search may not
    // silently adopt an adaptive cutoff and its diagnostics must be honest.
    CHECK(a.search.reason == EG_SEARCH_REASON_STABLE_CONVERGENCE ||
          a.search.reason == EG_SEARCH_REASON_COMPLETE);
    CHECK(b.search.reason == EG_SEARCH_REASON_COMPLETE);
    CHECK(b.search.completed_depth == budgeted.max_depth);
    if (a.search.reason == EG_SEARCH_REASON_STABLE_CONVERGENCE) {
        CHECK(a.search.completed_depth >= 5);
        CHECK(a.search.completed_depth < adaptive.max_depth);
        CHECK(a.search.nodes <= b.search.nodes);
    }
    CHECK(eg_ply_count(e.get()) == 2);

    // Tactical preflight MUST override either stopping policy.
    eg_reset(e.get());
    for (int i=0; i<4; ++i) {
        CHECK(eg_play(e.get(), i) == 1);
        CHECK(eg_play(e.get(), 15+i) == 1);
    }
    for (auto p : {adaptive, budgeted}) {
        const auto decision = run(e.get(), p);
        CHECK(decision.search.reason == EG_SEARCH_REASON_FORCED_WIN);
        CHECK(decision.search.move == 4);
    }
    std::cout << "ECLIPSE adaptive convergence: pure tracker, native opt-in, "
                 "budgeted preservation and forced win PASS\n";
}
