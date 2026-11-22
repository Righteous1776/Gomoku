// R26: the actual R25-273 forest executes inside the original C++ V2
// forced-threat + PVS search. This is NOT a Tianyuan strength certificate.
#include "eclipse_c_api.h"
#include "eclipse_r07_ranker.hpp"
#include <array>
#include <fstream>
#include <iostream>
#include <iterator>
#include <memory>
#include <stdexcept>
#include <string>

#define REQUIRE(cond) do { if (!(cond)) throw std::runtime_error("R25: " #cond); } while(false)
using Handle = std::unique_ptr<EGEngine, decltype(&eg_destroy)>;

static std::string read(const char *path) {
    std::ifstream stream(path, std::ios::binary);
    REQUIRE(stream.good());
    return {std::istreambuf_iterator<char>(stream), std::istreambuf_iterator<char>()};
}
static EGComputeRunV2 analyze(EGEngine *e) {
    EGComputePolicyV2 p{};
    p.size_bytes=sizeof(p);p.mode=EG_COMPUTE_MODE_BUDGETED;
    // The same Zenith search *geometry*. 400ms is a SHORT CI smoke,
    // NOT an equal-time 5700ms strength comparison.
    p.max_wall_time_ms=400;p.max_nodes=30000;p.max_depth=7;
    p.root_width=18;p.reply_width=30;p.continuation_width=20;
    p.forced_line_depth=6;p.candidate_radius=3;
    std::array<uint8_t,225> before{},after{};
    REQUIRE(eg_copy_board(e,before.data(),225)==225);
    EGComputeRunV2 result{};result.size_bytes=sizeof(result);
    REQUIRE(eg_analyze_compute_policy_v2(e,&p,nullptr,0,nullptr,0,&result)==1);
    REQUIRE(eg_copy_board(e,after.data(),225)==225);
    REQUIRE(before==after);
    REQUIRE(result.search.move>=0 && result.search.move<225);
    REQUIRE(before[result.search.move]==0);
    REQUIRE(result.search.nodes<=30000+225); // tactical preflight may visit roots
    REQUIRE(result.applied_policy.max_depth==7);
    REQUIRE(result.applied_policy.forced_line_depth==6);
    return result;
}
static void history(EGEngine *e,std::initializer_list<int> moves) {
    for(int m:moves) REQUIRE(eg_play(e,m)==1);
}
int main(int argc,char **argv) {
    REQUIRE(argc==3);
    const std::string r07=read(argv[1]);
    const std::string r25=read(argv[2]);
    REQUIRE(r07.size()==585541);
    REQUIRE(eclipse::research_r07::sha256(r07)==eclipse::research_r07::kR07SHA);
    REQUIRE(eclipse::research_r07::sha256(r25)==eclipse::research_r07::kR25SHA);
    REQUIRE(r25.size()>r07.size());
    Handle e(eg_create(),eg_destroy);
    REQUIRE(e!=nullptr);
    char sha[65]{};
    REQUIRE(eg_active_zenith_r25_sha256_v6(e.get(),sha,65)==0);
    REQUIRE(eg_load_zenith_r25_student_v6(
        e.get(),r07.data(),static_cast<int>(r07.size()),
        eclipse::research_r07::kR25SHA)==0);
    std::string tampered=r25;tampered[300]^=1;
    REQUIRE(eg_load_zenith_r25_student_v6(
        e.get(),tampered.data(),static_cast<int>(tampered.size()),
        eclipse::research_r07::kR25SHA)==0);
    REQUIRE(eg_load_zenith_r25_student_v6(
        e.get(),r25.data(),static_cast<int>(r25.size()),
        eclipse::research_r07::kR07SHA)==0);
    REQUIRE(eg_load_astra_r07_v5(
        e.get(),r25.data(),static_cast<int>(r25.size()),
        eclipse::research_r07::kR07SHA)==0);
    REQUIRE(eg_load_zenith_r25_student_v6(
        e.get(),r25.data(),static_cast<int>(r25.size()),
        eclipse::research_r07::kR25SHA)==1);
    REQUIRE(eg_research_ranker_v3(e.get())==EG_RESEARCH_RANKER_R25_ZENITH_STUDENT);
    REQUIRE(eg_active_zenith_r25_sha256_v6(e.get(),sha,65)==64);
    REQUIRE(std::string(sha)==eclipse::research_r07::kR25SHA);
    REQUIRE(eg_active_astra_r07_sha256_v5(e.get(),sha,65)==0);

    // Exact native 34D feature extraction. Guard the old 26D mapping and
    // the 8 R07 tactical additions against silent drift.
    std::array<uint8_t,225> cells{};
    for(auto m: {112,97,111,98})cells[m]=(m==112||m==111)?1:2;
    const auto f=eclipse::research_r07::features(cells,113,1);
    const std::array<double,34> reference = {
        1,3,0,0,8,0,0,0,3,2,1,0,0,0,1,2,1,0,
        14,6,4,1,0,0,0,1,0,0,0,0,0,3,0,0
    };
    REQUIRE(f==reference);

    history(e.get(),{112,97,111,98});
    auto quiet=analyze(e.get());
    REQUIRE(eg_ply_count(e.get())==4);
    REQUIRE(eg_zenith_r25_score_v6(e.get(),113)!=0);
    eg_reset(e.get());
    REQUIRE(eg_active_zenith_r25_sha256_v6(e.get(),sha,65)==0);
    REQUIRE(eg_load_zenith_r25_student_v6(e.get(),
        r25.data(),static_cast<int>(r25.size()),
        eclipse::research_r07::kR25SHA)==1);
    history(e.get(),{112,0,143,1,125,2,151,3});
    auto defend=analyze(e.get());
    REQUIRE(defend.search.reason==EG_SEARCH_REASON_FORCED_BLOCK);
    REQUIRE(defend.search.move==4);
    eg_reset(e.get());
    REQUIRE(eg_load_zenith_r25_student_v6(e.get(),
        r25.data(),static_cast<int>(r25.size()),
        eclipse::research_r07::kR25SHA)==1);
    history(e.get(),{0,15,1,16,2,17,3,18});
    auto attack=analyze(e.get());
    REQUIRE(attack.search.reason==EG_SEARCH_REASON_FORCED_WIN);
    REQUIRE(attack.search.move==4);

    // Verify old R07 remains a separate, still loadable identity.
    eg_reset(e.get());
    REQUIRE(eg_load_astra_r07_v5(e.get(),r07.data(),
        static_cast<int>(r07.size()),eclipse::research_r07::kR07SHA)==1);
    REQUIRE(eg_active_astra_r07_sha256_v5(e.get(),sha,65)==64);
    REQUIRE(std::string(sha)==eclipse::research_r07::kR07SHA);
    REQUIRE(eg_active_zenith_r25_sha256_v6(e.get(),sha,65)==0);
    std::cout << "R26 R25: genuine 273-tree weights, 34D, native PVS/VCF, exact SHA, legal outputs, forced win/block PASS\n";
}
