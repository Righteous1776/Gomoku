#include "eclipse_c_api.h"
#include "eclipse_r07_ranker.hpp"
#include <fstream>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#define REQUIRE(v) do {if(!(v))throw std::runtime_error("R07: " #v);}while(false)
using Engine=std::unique_ptr<EGEngine,decltype(&eg_destroy)>;
static EGComputeRunV2 search(EGEngine* e) {
    EGComputePolicyV2 p{};
    p.size_bytes=sizeof(p);p.mode=EG_COMPUTE_MODE_BUDGETED;
    p.max_wall_time_ms=250;p.max_nodes=25000;p.max_depth=3;
    p.root_width=6;p.reply_width=4;p.continuation_width=3;
    p.forced_line_depth=0;p.candidate_radius=2;
    EGComputeRunV2 out{};
    out.size_bytes=sizeof(out);
    REQUIRE(eg_analyze_compute_policy_v2(e,&p,nullptr,0,nullptr,0,&out)==1);
    REQUIRE(out.search.move>=0&&out.search.move<225);
    return out;
}
int main(int argc,char** argv) {
    REQUIRE(argc==2);
    REQUIRE(eclipse::research_r07::sha256("abc")==
      "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad");
    std::ifstream stream(argv[1],std::ios::binary);
    REQUIRE(stream.good());
    std::string bytes((std::istreambuf_iterator<char>(stream)),std::istreambuf_iterator<char>());
    REQUIRE(bytes.size()==585541);
    REQUIRE(eclipse::research_r07::sha256(bytes)==eclipse::research_r07::kR07SHA);
    Engine e(eg_create(),eg_destroy);
    REQUIRE(e!=nullptr);
    char digest[65]{};
    REQUIRE(eg_active_astra_r07_sha256_v5(e.get(),digest,65)==0);
    std::string corrupt=bytes;corrupt[100]^=1;
    REQUIRE(eg_load_astra_r07_v5(e.get(),corrupt.data(),static_cast<int>(corrupt.size()),
                                 eclipse::research_r07::kR07SHA)==0);
    REQUIRE(eg_load_astra_r07_v5(e.get(),bytes.data(),static_cast<int>(bytes.size()),
                                 eclipse::research_r07::kR07SHA)==1);
    REQUIRE(eg_research_ranker_v3(e.get())==EG_RESEARCH_RANKER_R07_ASTRA);
    REQUIRE(eg_active_astra_r07_sha256_v5(e.get(),digest,65)==64);
    REQUIRE(std::string(digest)==eclipse::research_r07::kR07SHA);
    const int center=eg_astra_r07_score_v5(e.get(),112);
    const int corner=eg_astra_r07_score_v5(e.get(),0);
    REQUIRE(center!=corner);
    REQUIRE(eg_play(e.get(),112)==1);
    REQUIRE(eg_play(e.get(),97)==1);
    REQUIRE(eg_astra_r07_score_v5(e.get(),112)==0);
    auto d=search(e.get());
    REQUIRE(d.search.move!=112&&d.search.move!=97);
    REQUIRE(eg_ply_count(e.get())==2);
    eg_reset(e.get());
    REQUIRE(eg_active_astra_r07_sha256_v5(e.get(),digest,65)==0);
    REQUIRE(eg_load_astra_r07_v5(e.get(),bytes.data(),static_cast<int>(bytes.size()),
                                 eclipse::research_r07::kR07SHA)==1);
    for(int x:{112,0,143,1,125,2,151,3})REQUIRE(eg_play(e.get(),x)==1);
    auto defend=search(e.get());
    REQUIRE(defend.search.reason==EG_SEARCH_REASON_FORCED_BLOCK);
    REQUIRE(defend.search.move==4);
    eg_reset(e.get());
    REQUIRE(eg_load_astra_r07_v5(e.get(),bytes.data(),static_cast<int>(bytes.size()),
                                 eclipse::research_r07::kR07SHA)==1);
    for(int i=0;i<4;++i){REQUIRE(eg_play(e.get(),i)==1);REQUIRE(eg_play(e.get(),i+15)==1);}
    auto attack=search(e.get());
    REQUIRE(attack.search.reason==EG_SEARCH_REASON_FORCED_WIN);
    REQUIRE(attack.search.move==4);
    std::cout<<"3.0 Astra R07: SHA256 verified, real LightGBM parsed, legal move, tactical win/block PASS\n";
}