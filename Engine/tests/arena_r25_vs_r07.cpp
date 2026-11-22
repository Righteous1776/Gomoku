// R26 actual two-weight C++ PVS/VCF FULL game arena.
// Both contestants execute the SAME engine and compute policy; ONLY the
// verified LightGBM checkpoint differs. Synthetic openings are side-swapped.
#include "eclipse_c_api.h"
#include "eclipse_r07_ranker.hpp"
#include <array>
#include <charconv>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <iterator>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
#define ENSURE(v) do { if (!(v)) throw std::runtime_error("R26 paired arena failed: " #v); } while(false)
using Handle = std::unique_ptr<EGEngine, decltype(&eg_destroy)>;
struct Opening { const char *name; std::vector<int> history; };
const std::array<Opening,6> openings{{
    {"orthogonal_one",{112,97}},{"diagonal_one",{112,98}},
    {"orthogonal_two",{112,82}},{"diagonal_two",{112,84}},
    {"cross_four",{112,97,111,98}},{"diagonal_four",{112,98,127,113}}
}};
std::string read_file(const std::string &path) {
    std::ifstream f(path,std::ios::binary);
    ENSURE(f.good());
    return {std::istreambuf_iterator<char>(f),std::istreambuf_iterator<char>()};
}
int number(const char *s) {
    int x=0;
    const auto n=std::char_traits<char>::length(s);
    auto parse=std::from_chars(s,s+n,x);
    if(parse.ec!=std::errc{}||parse.ptr!=s+n)throw std::runtime_error("bad int arg");
    return x;
}
EGComputePolicyV2 policy(int ms,int depth,int nodes) {
    EGComputePolicyV2 p{};
    p.size_bytes=sizeof(p);
    p.mode=EG_COMPUTE_MODE_BUDGETED;
    p.max_wall_time_ms=ms;p.max_nodes=nodes;p.max_depth=depth;
    p.root_width=18;p.reply_width=30;p.continuation_width=20;
    p.forced_line_depth=6;p.candidate_radius=3;
    return p;
}
void write_moves(const std::vector<int> &v) {
    std::cout<<"[";
    for(std::size_t i=0;i<v.size();++i) {
        if(i)std::cout<<",";
        std::cout<<v[i];
    }
    std::cout<<"]";
}
struct Game {
    int winner=3;
    std::uint64_t elapsed=0,nodes=0,forced=0,time_limits=0,search_calls=0;
    std::vector<int> moves;
};
Game play(const Opening &opening, const std::string &r07,
          const std::string &r25, bool student_black,
          int ms,int depth,int nodes) {
    Handle older(eg_create(),eg_destroy),student(eg_create(),eg_destroy);
    ENSURE(older && student);
    ENSURE(eg_load_astra_r07_v5(
        older.get(),r07.data(),static_cast<int>(r07.size()),
        eclipse::research_r07::kR07SHA)==1);
    ENSURE(eg_load_zenith_r25_student_v6(
        student.get(),r25.data(),static_cast<int>(r25.size()),
        eclipse::research_r07::kR25SHA)==1);
    char identity[65]{};
    ENSURE(eg_active_zenith_r25_sha256_v6(student.get(),identity,65)==64);
    ENSURE(std::string(identity)==eclipse::research_r07::kR25SHA);
    ENSURE(eg_research_ranker_v3(student.get())==EG_RESEARCH_RANKER_R25_ZENITH_STUDENT);
    ENSURE(eg_active_astra_r07_sha256_v5(older.get(),identity,65)==64);
    ENSURE(std::string(identity)==eclipse::research_r07::kR07SHA);

    Game g{};
    g.moves=opening.history;
    for(int m:opening.history) {
        ENSURE(eg_play(older.get(),m)==1);
        ENSURE(eg_play(student.get(),m)==1);
    }
    ENSURE(eg_status(older.get())==0);
    const auto p=policy(ms,depth,nodes);
    for(int count=static_cast<int>(g.moves.size());count<225;++count) {
        ENSURE(eg_status(older.get())==eg_status(student.get()));
        const int side=eg_to_move(older.get());
        ENSURE(side==1||side==2);
        ENSURE(side==eg_to_move(student.get()));
        EGEngine *selected=(((side==1)==student_black)?student.get():older.get());
        std::array<std::uint8_t,225> before{},after{};
        ENSURE(eg_copy_board(selected,before.data(),225)==225);
        EGComputeRunV2 result{};
        result.size_bytes=sizeof(result);
        ENSURE(eg_analyze_compute_policy_v2(
            selected,&p,nullptr,0,nullptr,0,&result)==1);
        ENSURE(eg_copy_board(selected,after.data(),225)==225);
        ENSURE(before==after);
        int move=result.search.move;
        ENSURE(move>=0&&move<225&&before[move]==0);
        g.search_calls++;
        g.elapsed+=result.search.elapsed_ms;
        g.nodes+=result.search.nodes;
        g.forced+=(result.search.reason==EG_SEARCH_REASON_FORCED_WIN||
                   result.search.reason==EG_SEARCH_REASON_FORCED_BLOCK);
        g.time_limits+=(result.search.reason==EG_SEARCH_REASON_TIME_LIMIT);
        ENSURE(eg_play(older.get(),move)==1);
        ENSURE(eg_play(student.get(),move)==1);
        g.moves.push_back(move);
        if(eg_status(older.get())!=0)break;
    }
    g.winner=eg_status(older.get());
    ENSURE(g.winner==eg_status(student.get()));
    ENSURE(g.winner>=1&&g.winner<=3);
    ENSURE(g.moves.size()<=225);
    return g;
}
void emit(const Opening&o,bool student_black,const Game&g,int ms,int depth,int nodes) {
    auto black=student_black?"R25":"R07";
    auto white=student_black?"R07":"R25";
    auto winner=g.winner==3?"draw":g.winner==1?black:white;
    std::cout<<"{\"type\":\"game\",\"schema\":\"eclipse.r26.same-engine-paired.v1\","
             <<"\"rules\":\"freestyle-15\",\"opening\":\""<<o.name
             <<"\",\"black\":\""<<black<<"\",\"white\":\""<<white
             <<"\",\"winner\":\""<<winner<<"\",\"winner_color\":"<<g.winner
             <<",\"plies\":"<<g.moves.size()
             <<",\"total_search_elapsed_ms\":"<<g.elapsed
             <<",\"total_nodes\":"<<g.nodes
             <<",\"search_calls\":"<<g.search_calls
             <<",\"forced_tactical_moves\":"<<g.forced
             <<",\"time_limit_responses\":"<<g.time_limits
             <<",\"policy\":{\"ms\":"<<ms<<",\"nodes\":"<<nodes
             <<",\"depth\":"<<depth
             <<",\"root_width\":18,\"reply_width\":30,\"continuation_width\":20,"
               "\"forced_line_depth\":6,\"candidate_radius\":3},\"moves\":";
    write_moves(g.moves);
    std::cout<<"}\n";
}
}
int main(int argc,char **argv) {
    try {
        std::string r07path,r25path;
        int ms=100,depth=3,nodes=30000,opening_count=2;
        for(int i=1;i<argc;++i) {
            std::string arg=argv[i];
            if(i+1>=argc)throw std::runtime_error("missing value");
            if(arg=="--r07")r07path=argv[++i];
            else if(arg=="--r25")r25path=argv[++i];
            else if(arg=="--ms")ms=number(argv[++i]);
            else if(arg=="--depth")depth=number(argv[++i]);
            else if(arg=="--nodes")nodes=number(argv[++i]);
            else if(arg=="--openings")opening_count=number(argv[++i]);
            else throw std::runtime_error("unknown parameter");
        }
        ENSURE(!r07path.empty()&&!r25path.empty());
        ENSURE(ms>=10&&ms<=5700&&depth>=2&&depth<=7&&
               nodes>=100&&nodes<=30000&&opening_count>=1&&opening_count<=6);
        const auto r07=read_file(r07path),r25=read_file(r25path);
        ENSURE(eclipse::research_r07::sha256(r07)==eclipse::research_r07::kR07SHA);
        ENSURE(eclipse::research_r07::sha256(r25)==eclipse::research_r07::kR25SHA);
        std::cout<<"{\"type\":\"meta\",\"schema\":\"eclipse.r26.same-engine-paired.v1\","
                 <<"\"model_r07_sha256\":\""<<eclipse::research_r07::kR07SHA
                 <<"\",\"model_r25_sha256\":\""<<eclipse::research_r07::kR25SHA
                 <<"\",\"games\":"<<2*opening_count
                 <<",\"paired_color_swaps\":true,\"real_full_games\":true,"
                   "\"source\":\"public_synthetic\",\"same_cpp_pvs_vcf_engine\":true,"
                   "\"certified_elo\":false}\n";
        int win=0,loss=0,draw=0;
        for(int i=0;i<opening_count;++i)
            for(bool student_black:{true,false}) {
                const auto game=play(openings[i],r07,r25,student_black,ms,depth,nodes);
                emit(openings[i],student_black,game,ms,depth,nodes);
                if(game.winner==3)++draw;
                else if((game.winner==1)==student_black)++win;
                else ++loss;
            }
        const double score=(win+0.5*draw)/static_cast<double>(2*opening_count);
        std::cout<<"{\"type\":\"summary\",\"model\":\"R25\",\"opponent\":\"R07\","
                 <<"\"wins\":"<<win<<",\"losses\":"<<loss<<",\"draws\":"<<draw
                 <<",\"games\":"<<2*opening_count<<",\"score_fraction\":"<<score
                 <<",\"qualification\":\"exploratory paired games; not certified Elo\"}\n";
        return 0;
    } catch(const std::exception&e) {
        std::cerr<<"R26 ARENA ERROR: "<<e.what()<<"\n";
        return 2;
    }
}
