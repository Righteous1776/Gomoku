#include "eclipse_c_api.h"
#include "search.hpp"
#include <array>
#include <iostream>
#include <memory>
#include <stdexcept>
#define CHECK(x) do { if (!(x)) throw std::runtime_error("Adaptive convergence: " #x); } while(0)
using Owner=std::unique_ptr<EGEngine,decltype(&eg_destroy)>;
using eclipse::AdaptiveSearchEvidence;
using eclipse::should_stop_adaptive;
static EGComputePolicyV2 policy() {
    EGComputePolicyV2 p{};
    p.size_bytes=sizeof(p);
    p.mode=EG_COMPUTE_MODE_BUDGETED;
    p.max_wall_time_ms=1000; // test fails safely if an actual search struggles
    p.max_nodes=15000;
    p.max_depth=4;
    p.root_width=3;
    p.reply_width=2;
    p.continuation_width=1;
    p.forced_line_depth=8; // must not monopolize a quiet position
    p.candidate_radius=2;
    return p;
}
int main() {
    // A timer does not determine convergence: incomplete or unstable
    // searches must keep thinking regardless of time already elapsed.
    CHECK(!should_stop_adaptive({0, 12, 8, 5000, 0, 6, 2000}));
    CHECK(!should_stop_adaptive({1, 2, 2, 5000, 0, 6, 2000}));
    CHECK(!should_stop_adaptive({1, 4, 1, 5000, 0, 6, 2000}));
    CHECK(!should_stop_adaptive({1, 4, 3, 30, 0, 6, 2000}));
    CHECK(should_stop_adaptive({1, 3, 2, 550, 0, 6, 2000}));
    CHECK(!should_stop_adaptive({2, 3, 3, 550, 0, 6, 2000}));
    CHECK(should_stop_adaptive({2, 4, 3, 550, 0, 6, 2000}));
    CHECK(!should_stop_adaptive({1, 3, 2, 5500, 4, 6, 2000}));
    CHECK(!should_stop_adaptive({1, 5, 3, 300, 4, 6, 2000}));
    CHECK(should_stop_adaptive({1, 5, 3, 1600, 4, 6, 2000}));
    CHECK(!should_stop_adaptive({2, 5, 3, 1600, 4, 6, 2000}));
    CHECK(should_stop_adaptive({2, 6, 3, 1900, 4, 6, 2000}));
    CHECK(!should_stop_adaptive({1, 7, 5, 7000, 0, 6, -6000000}));
    // The geometrical forced-win/unique block safety gate must always
    // outrank user preferences and native adaptive stopping.
    Owner engine(eg_create(),eg_destroy);
    CHECK(engine!=nullptr);
    CHECK(eg_adaptive_search_profile_v4(engine.get())==0);
    CHECK(eg_set_adaptive_search_profile_v4(engine.get(),-1)==0);
    CHECK(eg_set_adaptive_search_profile_v4(engine.get(),3)==0);
    CHECK(eg_set_adaptive_search_profile_v4(engine.get(),1)==1);
    CHECK(eg_adaptive_search_profile_v4(engine.get())==1);
    auto p=policy();
    EGComputeRunV2 result{};result.size_bytes=sizeof(result);
    // Two separated stones => quiet opening; 8-ply forcing-four proof has
    // no legal start and must be bypassed by the geometric threat predicate.
    CHECK(eg_play(engine.get(),112)==1);
    CHECK(eg_play(engine.get(),97)==1);
    CHECK(eg_analyze_compute_policy_v2(engine.get(),&p,
          nullptr,0,nullptr,0,&result)==1);
    CHECK(result.search.move>=0&&result.search.move<225);
    CHECK(result.applied_policy.max_wall_time_ms==1000);
    CHECK(eg_ply_count(engine.get())==2);
    eg_reset(engine.get());
    CHECK(eg_adaptive_search_profile_v4(engine.get())==0);
    CHECK(eg_set_adaptive_search_profile_v4(engine.get(),2)==1);
    // Rule-certified immediate win must be decided without waiting for
    // 30 seconds or for an arbitrary minimum number of search rounds.
    for(int i=0;i<4;++i) {
        CHECK(eg_play(engine.get(),i)==1);
        CHECK(eg_play(engine.get(),15+i)==1);
    }
    p.max_wall_time_ms=30000;
    CHECK(eg_analyze_compute_policy_v2(engine.get(),&p,
          nullptr,0,nullptr,0,&result)==1);
    CHECK(result.search.move==4);
    CHECK(result.search.reason==EG_SEARCH_REASON_FORCED_WIN);
    CHECK(result.search.elapsed_ms<2000);
    std::cout<<"Adaptive early stop: confidence, threat and immediate win PASS\n";
    return 0;
}
