#include "eclipse_c_api.h"
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
std::vector<int> parse_moves(std::string data){
    std::vector<int> result;std::size_t p=0;
    while(p<data.size()){
        const auto q=data.find(',',p);const auto token=data.substr(p,q==std::string::npos?std::string::npos:q-p);
        result.push_back(number(token));if(q==std::string::npos)break;p=q+1;
    }
    return result;
}
void usage(){std::cout<<"gomoku_cli --best <comma-separated-move-indices> [--ms 100]\n"
                       "gomoku_cli --selfplay --games N [--ms 10] [--out file.jsonl] [--seed N]\n";}
}

int main(int argc,char**argv){
try {
    bool best=false,selfplay=false;int games=1,ms=10,seed=42;std::string position,out;
    for(int i=1;i<argc;++i){const std::string a=argv[i];
        auto val=[&](){if(i+1>=argc)throw std::runtime_error("missing value: "+a);return std::string(argv[++i]);};
        if(a=="--best"){best=true;position=val();}
        else if(a=="--selfplay")selfplay=true;
        else if(a=="--games")games=number(val());
        else if(a=="--ms")ms=number(val());
        else if(a=="--seed")seed=number(val());
        else if(a=="--out")out=val();
        else if(a=="--help"){usage();return 0;}
        else throw std::runtime_error("unknown argument: "+a);
    }
    if(best==selfplay){usage();return 2;}
    if(ms<1||ms>20000||games<1||games>1000000)throw std::runtime_error("invalid limits");
    Engine engine{eg_create(),eg_destroy};if(!engine)throw std::runtime_error("out of memory");
    if(best){for(int m:parse_moves(position))if(!eg_play(engine.get(),m))throw std::runtime_error("illegal history");
        const int move=eg_best_move(engine.get(),ms);
        std::cout<<"{\"move\":"<<move<<",\"status\":"<<eg_status(engine.get())<<"}\n";
        return move<0?1:0;
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
