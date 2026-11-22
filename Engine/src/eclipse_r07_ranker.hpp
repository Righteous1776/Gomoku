#pragma once
// Experimental ECLIPSE 3.0 Astra / R07-249 LightGBM scorer.
// The 8 new features are ported from Training/research/r07/source/features34.py.
// The 26D legacy extractor comes from the local frozen C++ port; its exact
// parity to the missing original R04 data_pipeline.py is NOT yet certified.
// Unlike a model-picker alias, this code loads and traverses real R07 trees.
#include "eclipse_trained_ordering.hpp"
#include <array>
#include <cmath>
#include <cstddef>
#include <cstdint>
#include <iomanip>
#include <limits>
#include <memory>
#include <sstream>
#include <string>
#include <string_view>
#include <vector>

namespace eclipse::research_r07 {
inline constexpr char kR07SHA[] =
    "d4cea7f62e9e8ffc119d60861ce05df43aafdbdc280b51707dc1b7e40e5fc234";
// Minimal dependency-free SHA256. Verify ACTUAL text bytes before parsing.
inline std::string sha256(std::string_view data) {
    static constexpr std::uint32_t k[64] = {
        0x428a2f98,0x71374491,0xb5c0fbcf,0xe9b5dba5,0x3956c25b,0x59f111f1,0x923f82a4,0xab1c5ed5,
        0xd807aa98,0x12835b01,0x243185be,0x550c7dc3,0x72be5d74,0x80deb1fe,0x9bdc06a7,0xc19bf174,
        0xe49b69c1,0xefbe4786,0x0fc19dc6,0x240ca1cc,0x2de92c6f,0x4a7484aa,0x5cb0a9dc,0x76f988da,
        0x983e5152,0xa831c66d,0xb00327c8,0xbf597fc7,0xc6e00bf3,0xd5a79147,0x06ca6351,0x14292967,
        0x27b70a85,0x2e1b2138,0x4d2c6dfc,0x53380d13,0x650a7354,0x766a0abb,0x81c2c92e,0x92722c85,
        0xa2bfe8a1,0xa81a664b,0xc24b8b70,0xc76c51a3,0xd192e819,0xd6990624,0xf40e3585,0x106aa070,
        0x19a4c116,0x1e376c08,0x2748774c,0x34b0bcb5,0x391c0cb3,0x4ed8aa4a,0x5b9cca4f,0x682e6ff3,
        0x748f82ee,0x78a5636f,0x84c87814,0x8cc70208,0x90befffa,0xa4506ceb,0xbef9a3f7,0xc67178f2
    };
    std::array<std::uint32_t,8> h {
        0x6a09e667,0xbb67ae85,0x3c6ef372,0xa54ff53a,
        0x510e527f,0x9b05688c,0x1f83d9ab,0x5be0cd19
    };
    std::vector<unsigned char> padded(data.begin(), data.end());
    std::uint64_t bits = static_cast<std::uint64_t>(data.size()) * 8;
    padded.push_back(0x80);
    while (padded.size() % 64 != 56) padded.push_back(0);
    for (int i=7;i>=0;--i) padded.push_back(static_cast<unsigned char>(bits >> (8*i)));
    for (std::size_t off=0;off<padded.size();off+=64) {
        std::uint32_t w[64]{};
        for(int i=0;i<16;++i) {
            const auto pos=off+static_cast<std::size_t>(i)*4;
            w[i]=(static_cast<std::uint32_t>(padded[pos])<<24) |
                 (static_cast<std::uint32_t>(padded[pos+1])<<16) |
                 (static_cast<std::uint32_t>(padded[pos+2])<<8) |
                 static_cast<std::uint32_t>(padded[pos+3]);
        }
        auto rotr=[](std::uint32_t x,int n){ return (x>>n)|(x<<(32-n)); };
        for(int i=16;i<64;++i) {
            auto a=w[i-15],b=w[i-2];
            w[i]=(rotr(b,17)^rotr(b,19)^(b>>10))+w[i-7]+
                 (rotr(a,7)^rotr(a,18)^(a>>3))+w[i-16];
        }
        auto [a,b,c,d,e,f,g,hh]=h;
        for(int i=0;i<64;++i) {
            auto s1=rotr(e,6)^rotr(e,11)^rotr(e,25);
            auto ch=(e&f)^(~e&g);
            auto t1=hh+s1+ch+k[i]+w[i];
            auto s0=rotr(a,2)^rotr(a,13)^rotr(a,22);
            auto maj=(a&b)^(a&c)^(b&c);
            auto t2=s0+maj;
            hh=g;g=f;f=e;e=d+t1;d=c;c=b;b=a;a=t1+t2;
        }
        h[0]+=a;h[1]+=b;h[2]+=c;h[3]+=d;
        h[4]+=e;h[5]+=f;h[6]+=g;h[7]+=hh;
    }
    static constexpr char hex[]="0123456789abcdef";
    std::string result;
    result.reserve(64);
    for(auto value:h)for(int shift=28;shift>=0;shift-=4)
        result.push_back(hex[(value>>shift)&15]);
    return result;
}
struct Tree {
    std::vector<int> features, decisions, left, right;
    std::vector<double> thresholds, leaves;
    int expected_leaves=0;
};
struct Forest {
    std::vector<Tree> trees;
    static bool parse_numbers(const std::string &line, const char* key,
                              std::vector<int> &out) {
        std::string_view v(line), prefix(key);
        if (v.substr(0,prefix.size())!=prefix) return false;
        std::istringstream input{line.substr(prefix.size())};
        int x;
        while(input>>x)out.push_back(x);
        return input.eof() && !out.empty();
    }
    static bool parse_numbers(const std::string &line, const char* key,
                              std::vector<double> &out) {
        std::string_view v(line),prefix(key);
        if(v.substr(0,prefix.size())!=prefix)return false;
        std::istringstream input{line.substr(prefix.size())};
        double x;
        while(input>>x) {
            if(!std::isfinite(x))return false;
            out.push_back(x);
        }
        return input.eof() && !out.empty();
    }
    bool load(std::string_view source) {
        if(source.size()<100000||source.size()>2000000||sha256(source)!=kR07SHA)
            return false;
        std::istringstream input{std::string(source)};
        std::string line;
        bool header34=false;
        trees.clear();
        while(std::getline(input,line)) {
            if(line=="max_feature_idx=33")header34=true;
            if(line.rfind("Tree=",0)==0) {
                int idx=-1;
                try{idx=std::stoi(line.substr(5));}catch(...){return false;}
                if(idx!=static_cast<int>(trees.size())||idx>=249)return false;
                trees.emplace_back();
            }
            if(trees.empty())continue;
            Tree &t=trees.back();
            if(line.rfind("num_leaves=",0)==0) {
                try{t.expected_leaves=std::stoi(line.substr(11));}catch(...){return false;}
            } else if(line.rfind("split_feature=",0)==0) {
                if(!parse_numbers(line,"split_feature=",t.features))return false;
            } else if(line.rfind("threshold=",0)==0) {
                if(!parse_numbers(line,"threshold=",t.thresholds))return false;
            } else if(line.rfind("decision_type=",0)==0) {
                if(!parse_numbers(line,"decision_type=",t.decisions))return false;
            } else if(line.rfind("left_child=",0)==0) {
                if(!parse_numbers(line,"left_child=",t.left))return false;
            } else if(line.rfind("right_child=",0)==0) {
                if(!parse_numbers(line,"right_child=",t.right))return false;
            } else if(line.rfind("leaf_value=",0)==0) {
                if(!parse_numbers(line,"leaf_value=",t.leaves))return false;
            }
        }
        if(!header34||trees.size()!=249)return false;
        for(const Tree&t:trees) {
            auto n=t.features.size();
            if(n==0||n>256||t.expected_leaves!=static_cast<int>(n+1)||
               t.thresholds.size()!=n||t.decisions.size()!=n||
               t.left.size()!=n||t.right.size()!=n||
               t.leaves.size()!=n+1)return false;
            for(std::size_t i=0;i<n;++i) {
                if(t.features[i]<0||t.features[i]>=34 ||
                    (t.decisions[i]&1)!=0)return false; // categorical unsupported
                for(int child:{t.left[i],t.right[i]})
                    if(child>=0 ? child>=static_cast<int>(n)
                                : (-child-1)>=static_cast<int>(t.leaves.size()))
                        return false;
            }
        }
        return true;
    }
    double raw(const std::array<double,34> &f) const {
        if(trees.size()!=249)return std::numeric_limits<double>::quiet_NaN();
        double total=0;
        for(const Tree&t:trees) {
            int node=0;
            for(std::size_t steps=0;steps<=t.features.size();++steps) {
                if(node<0) {total+=t.leaves[-node-1];break;}
                if(node>=static_cast<int>(t.features.size()))
                    return std::numeric_limits<double>::quiet_NaN();
                const double val=f[t.features[node]];
                const bool goleft=std::isnan(val)
                    ? ((t.decisions[node]&2)!=0)
                    : val<=t.thresholds[node];
                node=goleft?t.left[node]:t.right[node];
                if(steps==t.features.size())
                    return std::numeric_limits<double>::quiet_NaN();
            }
        }
        return total;
    }
};
// Exact R07 features 26..33. Features 0..25 use the available frozen port
// (likely same positional semantics) until original R04 parity probes arrive.
inline std::array<double,34> features(const std::array<std::uint8_t,225> &board,
                                      int index,int side) {
    std::array<double,34> x{};
    if(index<0||index>=225||board[index]!=0||(side!=1&&side!=2))return x;
    const auto base=trained_model::features(board,index,side);
    for(std::size_t i=0;i<base.size();++i)x[i]=base[i];
    constexpr int drs[4]={0,1,1,1};
    constexpr int dcs[4]={1,0,1,-1};
    const int row=index/15,col=index%15,foe=3-side;
    int exact_win=0,must_block=0,own_three=0,own_four=0,enemy_three_block=0;
    std::array<int,20> holes{};
    int hole_count=0;
    for(int axis=0;axis<4;++axis) {
        const int dr=drs[axis],dc=dcs[axis];
        for(int offset=0;offset<5;++offset) {
            const int rr=row-offset*dr,cc=col-offset*dc;
            if(rr<0||rr>=15||cc<0||cc>=15||
               rr+4*dr<0||rr+4*dr>=15||cc+4*dc<0||cc+4*dc>=15)continue;
            int own=0,other=0,empty=0,last_empty=-1;
            for(int step=0;step<5;++step) {
                const int loc=(rr+step*dr)*15+cc+step*dc;
                const int value=loc==index?side:board[loc];
                if(value==side)++own;
                else if(value==foe)++other;
                else {++empty;last_empty=loc;}
            }
            if(other==0) {
                if(own==5)++exact_win;
                if(own==4&&empty==1) {
                    ++own_four;
                    bool seen=false;
                    for(int j=0;j<hole_count;++j)
                        if(holes[j]==last_empty){seen=true;break;}
                    if(!seen&&hole_count<20)holes[hole_count++]=last_empty;
                }
                if(own==3&&empty==2)++own_three;
            }
            if(own==1&&other==4)++must_block;
            if(own==1&&other==3&&empty==1)++enemy_three_block;
        }
    }
    x[26]=exact_win>0?1:0;
    x[27]=must_block>0?1:0;
    x[28]=hole_count;
    x[29]=enemy_three_block;
    x[30]=hole_count>=2?1:0;
    x[31]=own_three;
    x[32]=own_four;
    x[33]=exact_win*2+must_block;
    return x;
}
inline int score(const Forest &forest,const std::array<std::uint8_t,225>&board,
                 int move,int side) {
    if(move<0||move>=225||board[move]!=0||(side!=1&&side!=2))return 0;
    double v=forest.raw(features(board,move,side));
    if(!std::isfinite(v))return 0;
    return static_cast<int>(std::clamp(std::round(v*10000.0),-20000.0,20000.0));
}
} // namespace eclipse::research_r07
