// ECLIPSE V9 actual match arena: FULL GAMES on a real 15x15 C++ V2 engine.
// Public, synthetic openings only; no VeilLink training files required.
// A/B colors are swapped on each identical opening. Equal per-move
// wall/node/depth parameters; no Elo claims from this small cohort.
#include "eclipse_c_api.h"
#include <algorithm>
#include <array>
#include <charconv>
#include <cstdint>
#include <iostream>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
struct Opening {
    const char* name;
    std::vector<int> moves;
};
const std::array<Opening, 6> openings{{
    {"orthogonal_one", {112,97}},
    {"diagonal_one", {112,98}},
    {"orthogonal_two", {112,82}},
    {"diagonal_two", {112,84}},
    {"cross_four", {112,97,111,98}},
    {"diagonal_four", {112,98,127,113}}
}};
const std::array<const char*,3> names{{"R10","Astra","Sol"}};
struct Pair{int a,b;};
const std::array<Pair,3> pairs{{{1,2},{1,0},{2,0}}};
struct Totals{
    int wins=0, losses=0, draws=0, games=0;
    std::uint64_t nodes=0, elapsed=0, searches=0, full_depth=0, time_limits=0;
};
int parse(const char* text) {
    int value=0;
    const auto end=text+std::char_traits<char>::length(text);
    const auto parsed=std::from_chars(text,end,value);
    if(parsed.ec!=std::errc{}||parsed.ptr!=end)
        throw std::runtime_error("invalid numeric argument");
    return value;
}
EGComputePolicyV2 make_policy(int ms) {
    EGComputePolicyV2 p{};
    p.size_bytes=sizeof(p);
    p.mode=EG_COMPUTE_MODE_BUDGETED;
    p.max_wall_time_ms=ms;
    p.max_nodes=18000;
    p.max_depth=3;
    p.root_width=8;
    p.reply_width=6;
    p.continuation_width=4;
    p.forced_line_depth=2;
    p.candidate_radius=2;
    return p;
}
void print_moves(const std::vector<int>&moves) {
    std::cout<<"[";
    for(std::size_t i=0;i<moves.size();++i) {
        if(i) std::cout<<",";
        std::cout<<moves[i];
    }
    std::cout<<"]";
}
struct Game{
    int outcome=0, plies=0;
    std::uint64_t nodes=0,elapsed=0,searches=0,full_depth=0,time_limits=0;
    std::vector<int> moves;
};
Game play(const Opening&opening, int black, int white, int ms) {
    std::unique_ptr<EGEngine,decltype(&eg_destroy)> game(eg_create(),eg_destroy);
    if(!game)throw std::runtime_error("eg_create failed");
    Game result{};
    for(const int move:opening.moves) {
        if(!eg_play(game.get(),move))
            throw std::runtime_error(std::string("bad synthetic opening: ")+opening.name);
        result.moves.push_back(move);
    }
    if(eg_status(game.get())!=0)
        throw std::runtime_error("synthetic opening unexpectedly terminal");
    const auto policy=make_policy(ms);
    while(eg_status(game.get())==0) {
        const int turn=eg_to_move(game.get());
        if(turn!=1&&turn!=2)throw std::runtime_error("invalid turn");
        const int model=turn==1?black:white;
        if(!eg_select_research_ranker_v3(game.get(),model) ||
           eg_research_ranker_v3(game.get())!=model)
            throw std::runtime_error("model selection failed");

        std::array<std::uint8_t,225> before{},after{};
        if(eg_copy_board(game.get(),before.data(),225)!=225)
            throw std::runtime_error("pre-search board copy failed");
        EGComputeRunV2 response{};
        response.size_bytes=sizeof(response);
        if(!eg_analyze_compute_policy_v2(
            game.get(),&policy,nullptr,0,nullptr,0,&response))
            throw std::runtime_error("V2 analysis failed or cancelled");
        if(eg_copy_board(game.get(),after.data(),225)!=225 || before!=after)
            throw std::runtime_error("V2 search mutated the board");
        const int move=response.search.move;
        if(move<0||move>=225||before[move]||!eg_play(game.get(),move))
            throw std::runtime_error("V2 generated illegal move");

        result.moves.push_back(move);
        ++result.searches;
        result.nodes+=response.search.nodes;
        result.elapsed+=response.search.elapsed_ms;
        result.full_depth+=response.search.completed_depth;
        result.time_limits+=response.search.reason==EG_SEARCH_REASON_TIME_LIMIT;
        if(result.moves.size()>225)
            throw std::runtime_error("more than 225 moves!");
    }
    result.outcome=eg_status(game.get());
    result.plies=eg_ply_count(game.get());
    if(result.outcome<1||result.outcome>3||
       result.plies!=static_cast<int>(result.moves.size()))
        throw std::runtime_error("invalid terminal state");
    return result;
}
void accumulate(Totals& t,const Game& g,int contestant,int black,int white) {
    const int actual=g.outcome;
    ++t.games;
    if(actual==3)++t.draws;
    else if((actual==1&&contestant==black) ||
            (actual==2&&contestant==white))++t.wins;
    else ++t.losses;
    t.nodes+=g.nodes;
    t.elapsed+=g.elapsed;
    t.searches+=g.searches;
    t.full_depth+=g.full_depth;
    t.time_limits+=g.time_limits;
}
void emit_game(const Opening& opening,int black,int white,const Game& game,int ms) {
    std::cout<<"{\"type\":\"game\",\"generation\":\"V9\",\"rules\":\"freestyle-15\""
             <<",\"opening\":\""<<opening.name
             <<"\",\"black\":\""<<names[black]
             <<"\",\"white\":\""<<names[white]
             <<"\",\"winner\":\""
             <<(game.outcome==3?"draw":names[game.outcome==1?black:white])
             <<"\",\"winner_color\":"<<game.outcome
             <<",\"plies\":"<<game.plies
             <<",\"searched_moves\":"<<game.searches
             <<",\"total_nodes\":"<<game.nodes
             <<",\"total_search_elapsed_ms\":"<<game.elapsed
             <<",\"completed_depth_sum\":"<<game.full_depth
             <<",\"time_limit_responses\":"<<game.time_limits
             <<",\"budget_ms_per_move\":"<<ms
             <<",\"moves\":";
    print_moves(game.moves);
    std::cout<<"}\n";
}
void emit_summary(const Pair&pair,const Totals&stat) {
    std::cout<<"{\"type\":\"summary\",\"model\":\""<<names[pair.a]
             <<"\",\"opponent\":\""<<names[pair.b]
             <<"\",\"games\":"<<stat.games
             <<",\"wins\":"<<stat.wins
             <<",\"losses\":"<<stat.losses
             <<",\"draws\":"<<stat.draws
             <<",\"total_nodes\":"<<stat.nodes
             <<",\"total_search_elapsed_ms\":"<<stat.elapsed
             <<",\"searched_moves\":"<<stat.searches
             <<",\"completed_depth_sum\":"<<stat.full_depth
             <<",\"time_limit_responses\":"<<stat.time_limits<<"}\n";
}
} // namespace
int main(int argc,char**argv) {
    try {
        int ms=70,opening_limit=4;
        for(int i=1;i<argc;++i) {
            const std::string a=argv[i];
            if(a=="--ms"&&i+1<argc)ms=parse(argv[++i]);
            else if(a=="--openings"&&i+1<argc)opening_limit=parse(argv[++i]);
            else throw std::runtime_error("usage: eclipse_v9_arena [--ms 70] [--openings 1..6]");
        }
        if(ms<10||ms>2000||opening_limit<1||
           opening_limit>static_cast<int>(openings.size()))
            throw std::runtime_error("budget/opening count outside safe research range");
        std::cout<<"{\"type\":\"meta\",\"generation\":\"V9\","
                   "\"models\":[\"Astra\",\"Sol\",\"R10\"],"
                   "\"policy\":{\"max_wall_time_ms\":"<<ms
                 <<",\"max_nodes\":18000,\"max_depth\":3,"
                   "\"root_width\":8,\"reply_width\":6,"
                   "\"continuation_width\":4,\"forced_line_depth\":2,"
                   "\"candidate_radius\":2},\"openings\":"<<opening_limit
                 <<",\"paired_color_swaps\":true,"
                   "\"real_full_games\":true,"
                   "\"production_checkpoint_attested\":false,"
                   "\"source\":\"public_synthetic\"}\n";
        for(const auto& pair:pairs) {
            Totals stats{};
            for(int i=0;i<opening_limit;++i) {
                for(int flipped=0;flipped<2;++flipped) {
                    const int black=flipped?pair.b:pair.a;
                    const int white=flipped?pair.a:pair.b;
                    const auto game=play(openings[i],black,white,ms);
                    emit_game(openings[i],black,white,game,ms);
                    accumulate(stats,game,pair.a,black,white);
                }
            }
            if(stats.games!=opening_limit*2 ||
               stats.wins+stats.losses+stats.draws!=stats.games)
                throw std::runtime_error("invalid aggregate match counts");
            emit_summary(pair,stats);
        }
        return 0;
    } catch(const std::exception& e) {
        std::cerr<<"V9_ARENA_ERROR: "<<e.what()<<"\n";
        return 2;
    }
}
