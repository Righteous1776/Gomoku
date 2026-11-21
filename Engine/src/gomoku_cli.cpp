#include "eclipse_c_api.h"
#include <array>
#include <cstdint>
#include <limits>
#include <charconv>
#include <fstream>
#include <iostream>
#include <memory>
#include <random>
#include <stdexcept>
#include <string>
#include <vector>

namespace {
using Engine=std::unique_ptr<EGEngine,decltype(&eg_destroy)>;
int number(const std::string &s){int v=0;auto p=std::from_chars(s.data(),s.data()+s.size(),v);if(p.ec!=std::errc{}||p.ptr!=s.data()+s.size())throw std::runtime_error("invalid integer: "+s);return v;}
std::int64_t signed64(const std::string &s) {
    std::int64_t v=0;
    auto p=std::from_chars(s.data(),s.data()+s.size(),v);
    if(p.ec!=std::errc{} || p.ptr!=s.data()+s.size())
        throw std::runtime_error("invalid signed 64 bit number");
    return v;
}
std::uint64_t unsigned64(const std::string &s) {
    std::uint64_t v=0;
    auto p=std::from_chars(s.data(),s.data()+s.size(),v);
    if(p.ec!=std::errc{} || p.ptr!=s.data()+s.size())
        throw std::runtime_error("invalid unsigned 64 bit number");
    return v;
}
EGComputePolicyV2 parse_trainer_policy(const std::string &raw) {
    std::vector<std::string> parts;
    for(std::size_t p=0; p<=raw.size();) {
        auto at=raw.find(',',p);
        parts.push_back(raw.substr(p,at==std::string::npos?at:at-p));
        if(at==std::string::npos)break;
        p=at+1;
    }
    if(parts.size()!=9) throw std::runtime_error("policy requires nine comma-separated fields");
    EGComputePolicyV2 policy{};
    policy.size_bytes=sizeof(policy);
    policy.mode=static_cast<std::uint32_t>(number(parts[0]));
    policy.max_wall_time_ms=signed64(parts[1]);
    policy.max_nodes=unsigned64(parts[2]);
    policy.max_depth=number(parts[3]);
    policy.root_width=number(parts[4]);
    policy.reply_width=number(parts[5]);
    policy.continuation_width=number(parts[6]);
    policy.forced_line_depth=number(parts[7]);
    policy.candidate_radius=number(parts[8]);
    return policy;
}
std::vector<int> parse_moves(std::string data){
    std::vector<int> result;std::size_t p=0;
    while(p<data.size()){
        const auto q=data.find(',',p);const auto token=data.substr(p,q==std::string::npos?std::string::npos:q-p);
        result.push_back(number(token));if(q==std::string::npos)break;p=q+1;
    }
    return result;
}
void usage(){std::cout<<"gomoku_cli --best <comma-separated-move-indices> [--ms 100] (0 = no time ceiling)\n"
                       "gomoku_cli --best <moves> --policy-v2 <mode,ms,nodes,depth,root,reply,continuation,forcing,radius> [--research-ranker v9-astra|v9-sol]\n"
                       "gomoku_cli --state <comma-separated-move-indices> (rules-only replay)\n"
                       "gomoku_cli --selfplay --games N [--ms 10] [--out file.jsonl] [--seed N]\n";}
}

int main(int argc,char**argv){
try {
    bool best=false,selfplay=false,state_mode=false,has_policy=false,explicit_ms=false;
    int games=1,ms=10,seed=42;std::string position,out;
    int research_ranker = EG_RESEARCH_RANKER_LEGACY;
    bool explicit_research_ranker = false;
    EGComputePolicyV2 trainer_policy{};
    for(int i=1;i<argc;++i){const std::string a=argv[i];
        auto val=[&](){if(i+1>=argc)throw std::runtime_error("missing value: "+a);return std::string(argv[++i]);};
        if(a=="--best"){best=true;position=val();}
        else if(a=="--state"){state_mode=true;position=val();}
        else if(a=="--selfplay")selfplay=true;
        else if(a=="--games")games=number(val());
        else if(a=="--ms"){explicit_ms=true;ms=number(val());}
        else if(a=="--policy-v2"){has_policy=true;trainer_policy=parse_trainer_policy(val());}
        else if(a=="--research-ranker"){
            if(explicit_research_ranker)throw std::runtime_error("duplicate research ranker");
            explicit_research_ranker=true;
            const auto name=val();
            if(name=="v9-astra")research_ranker=EG_RESEARCH_RANKER_V9_ASTRA;
            else if(name=="v9-sol")research_ranker=EG_RESEARCH_RANKER_V9_SOL;
            else throw std::runtime_error("unsupported research ranker: "+name);
        }
        else if(a=="--seed")seed=number(val());
        else if(a=="--out")out=val();
        else if(a=="--help"){usage();return 0;}
        else throw std::runtime_error("unknown argument: "+a);
    }
    if(static_cast<int>(best)+static_cast<int>(selfplay)+static_cast<int>(state_mode)!=1){usage();return 2;}
    // 0 is the explicit trainer-adaptive, no-wall-clock-ceiling search mode.
    // The CLI does not silently cap training-agent selected budgets at 20s.
    if(ms<0||games<1||games>1000000)throw std::runtime_error("invalid limits");
    if(has_policy && (!best || explicit_ms))
        throw std::runtime_error("--policy-v2 only works with --best and without --ms");
    if(explicit_research_ranker && (!has_policy || !best))
        throw std::runtime_error("--research-ranker requires --best and --policy-v2");
    Engine engine{eg_create(),eg_destroy};if(!engine)throw std::runtime_error("out of memory");
    if(state_mode){
        const auto parsed=parse_moves(position);
        std::vector<int32_t> moves(parsed.begin(),parsed.end());
        std::array<uint8_t,225> cells{};
        int32_t turn=0,status=-1;
        if(!eg_rules_replay_v1(moves.data(),static_cast<int32_t>(moves.size()),
                cells.data(),static_cast<int32_t>(cells.size()),&turn,&status)){
            throw std::runtime_error("illegal history");
        }
        std::cout<<"{\"rules_abi\":"<<eg_rules_abi_version()<<",\"status\":"<<status
                 <<",\"to_move\":"<<turn<<",\"plies\":"<<moves.size()<<",\"board\":[";
        for(size_t i=0;i<cells.size();++i) {
            if(i)std::cout<<",";
            std::cout<<static_cast<int>(cells[i]);
        }
        std::cout<<"]}\n";
        return 0;
    }
    if(best){for(int m:parse_moves(position))if(!eg_play(engine.get(),m))throw std::runtime_error("illegal history");
        if(has_policy) {
            if(explicit_research_ranker &&
               !eg_select_research_ranker_v3(engine.get(),research_ranker))
                throw std::runtime_error("research scorer selection failed");
            EGComputeRunV2 outcome{};
            outcome.size_bytes=sizeof(outcome);
            if(!eg_analyze_compute_policy_v2(
                engine.get(),&trainer_policy,nullptr,0,nullptr,0,&outcome))
                throw std::runtime_error("invalid or cancelled trainer search policy");
            const auto &p=outcome.applied_policy;
            const auto &d=outcome.search;
            std::cout<<"{\"move\":"<<d.move<<",\"status\":"<<eg_status(engine.get())
                     <<",\"elapsed_ms\":"<<d.elapsed_ms<<",\"nodes\":"<<d.nodes
                     <<",\"completed_depth\":"<<d.completed_depth
                     <<",\"applied_compute_policy\":{\"mode\":"<<p.mode
                     <<",\"max_wall_time_ms\":"<<p.max_wall_time_ms
                     <<",\"max_nodes\":"<<p.max_nodes
                     <<",\"max_depth\":"<<p.max_depth
                     <<",\"root_width\":"<<p.root_width
                     <<",\"reply_width\":"<<p.reply_width
                     <<",\"continuation_width\":"<<p.continuation_width
                     <<",\"forced_line_depth\":"<<p.forced_line_depth
                     <<",\"candidate_radius\":"<<p.candidate_radius
                     <<"}" << (explicit_research_ranker
                         ? (research_ranker==EG_RESEARCH_RANKER_V9_ASTRA
                             ? ",\\\"research_ranker\\\":\\\"v9-astra\\\"" : ",\\\"research_ranker\\\":\\\"v9-sol\\\"") : "")
                     << ",\\\"engine_revision\\\":\\\""<<eg_engine_revision()
                     <<"\"}\n";
            return d.move<0?1:0;
        }
        EGSearchDiagnosticsV1 diagnostics{};
        diagnostics.size_bytes=sizeof(EGSearchDiagnosticsV1);
        if(!eg_best_move_diagnostics_v1(engine.get(),ms,&diagnostics))
            throw std::runtime_error("diagnostic search failed");
        std::cout<<"{\"move\":"<<diagnostics.move<<",\"status\":"<<eg_status(engine.get())
                 <<",\"elapsed_ms\":"<<diagnostics.elapsed_ms
                 <<",\"nodes\":"<<diagnostics.nodes
                 <<",\"completed_depth\":"<<diagnostics.completed_depth
                 <<",\"budget_ms\":"<<ms
                 <<",\"engine_revision\":\""<<eg_engine_revision()<<"\"}\n";
        return diagnostics.move<0?1:0;
    }
    std::ofstream output;
    if(!out.empty()){output.open(out,std::ios::app);if(!output)throw std::runtime_error("cannot open output");}
    std::ostream &stream=out.empty()?std::cout:output;
    std::mt19937 rng(static_cast<unsigned>(seed));
    for(int g=0;g<games;++g){eg_reset(engine.get());std::vector<int> moves;
        const int opening=std::vector<int>{112,111,97,127}[rng()%4];
        eg_play(engine.get(),opening);moves.push_back(opening);
        while(eg_status(engine.get())==0){
            int m=eg_best_move(engine.get(),ms);
            if(m<0||!eg_play(engine.get(),m))throw std::runtime_error("search generated illegal move");
            moves.push_back(m);
        }
        stream<<"{\"schema\":\"eclipse.selfplay.v1\",\"rules\":\"freestyle-15\",\"source\":\"cpp-prototype\",\"seed\":"<<seed<<",\"game\":"<<g<<",\"winner\":"<<eg_status(engine.get())<<",\"moves\":[";
        for(std::size_t k=0;k<moves.size();++k){if(k)stream<<",";stream<<moves[k];}
        stream<<"]}\n";
    }
    return 0;
} catch(const std::exception &e){std::cerr<<"ERROR: "<<e.what()<<"\n";return 2;}
}
