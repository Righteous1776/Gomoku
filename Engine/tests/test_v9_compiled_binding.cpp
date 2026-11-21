#include "eclipse_c_api.h"
#include <array>
#include <cstring>
#include <iostream>
#include <memory>
#include <stdexcept>

#define REQUIRE(x) do { if(!(x)) throw std::runtime_error(#x); } while(0)

using Engine=std::unique_ptr<EGEngine,decltype(&eg_destroy)>;
static constexpr char kAstra[]=
    "d50190d02bf6ebd6f447d84a2920184964ac9cff1dcc0712b0076cec326a177d";
static constexpr char kSol[]=
    "074140fa99d52143ce3b887a553f1f11586973096baaada6476f97004e4b4fdd";

void check(const char* wanted,int model) {
    Engine engine(eg_create(),eg_destroy);
    REQUIRE(engine);
    char buf[65]{};
    char poison[65]{};
    std::memset(poison,'?',64);
    REQUIRE(!eg_active_compiled_v9_sha256_v4(engine.get(),buf,65));
    REQUIRE(!eg_select_compiled_v9_model_v4(nullptr,model,wanted));
    REQUIRE(!eg_select_compiled_v9_model_v4(engine.get(),0,wanted));
    REQUIRE(!eg_select_compiled_v9_model_v4(engine.get(),model,nullptr));
    REQUIRE(!eg_select_compiled_v9_model_v4(engine.get(),model,poison));
    REQUIRE(!eg_active_compiled_v9_sha256_v4(engine.get(),buf,65));
    REQUIRE(eg_select_compiled_v9_model_v4(engine.get(),model,wanted));
    REQUIRE(eg_research_ranker_v3(engine.get())==model);
    REQUIRE(eg_active_compiled_v9_sha256_v4(engine.get(),buf,65)==64);
    REQUIRE(std::strcmp(buf,wanted)==0);
    REQUIRE(!eg_active_compiled_v9_sha256_v4(engine.get(),buf,64));
    // A *wrong* lineage must not silently rebind or destroy an existing model.
    const char* other=model==EG_RESEARCH_RANKER_V9_ASTRA?kSol:kAstra;
    REQUIRE(!eg_select_compiled_v9_model_v4(engine.get(),model,other));
    REQUIRE(eg_active_compiled_v9_sha256_v4(engine.get(),buf,65)==64);
    REQUIRE(std::strcmp(buf,wanted)==0);
    // This really runs the V2 search on a non-terminal Swift-compatible board.
    REQUIRE(eg_play(engine.get(),112)==1);
    REQUIRE(eg_play(engine.get(),97)==1);
    EGComputePolicyV2 policy{};
    policy.size_bytes=sizeof(policy);
    policy.mode=EG_COMPUTE_MODE_BUDGETED;
    policy.max_wall_time_ms=200;
    policy.max_nodes=20000;
    policy.max_depth=2;
    policy.root_width=8;
    policy.reply_width=6;
    policy.continuation_width=4;
    policy.forced_line_depth=0;
    policy.candidate_radius=2;
    EGComputeRunV2 result{};
    result.size_bytes=sizeof(result);
    REQUIRE(eg_analyze_compute_policy_v2(
        engine.get(),&policy,nullptr,0,nullptr,0,&result)==1);
    REQUIRE(result.search.move>=0&&result.search.move<225);
    REQUIRE(eg_active_compiled_v9_sha256_v4(engine.get(),buf,65)==64);
    REQUIRE(eg_select_research_ranker_v3(engine.get(),model));
    REQUIRE(!eg_active_compiled_v9_sha256_v4(engine.get(),buf,65));
    REQUIRE(eg_select_compiled_v9_model_v4(engine.get(),model,wanted));
    eg_reset(engine.get());
    REQUIRE(eg_research_ranker_v3(engine.get())==0);
    REQUIRE(!eg_active_compiled_v9_sha256_v4(engine.get(),buf,65));
}

int main() {
    check(kAstra,EG_RESEARCH_RANKER_V9_ASTRA);
    check(kSol,EG_RESEARCH_RANKER_V9_SOL);
    std::cout<<"PASS: real Astra/Sol compiled forest binding, unique SHA and "
                "C++ V2 search, selector invalidation, reset and fail-closed\n";
}
