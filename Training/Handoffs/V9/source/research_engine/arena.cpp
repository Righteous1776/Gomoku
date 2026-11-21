// LOCAL RESEARCH ARENA: NOT the repository's production Swift or R15 C++ engine.
// Freestyle Gomoku 15x15, deterministic legal full games, forced immediate win/block.
// Identical C++ search and evaluation; only the selected 26-feature LightGBM ordering differs.
#include <array>
#include <algorithm>
#include <chrono>
#include <cmath>
#include <cstdint>
#include <iostream>
#include <iomanip>
#include <numeric>
#include <random>
#include <string>
#include <vector>
#include <cstdlib>
#include <cassert>
using Board=std::array<std::uint8_t,225>;
using Clock=std::chrono::steady_clock;
struct Node{int feature;double threshold;int left,right;double value;};
#include "astra_old.inc"
#include "astra_new.inc"
#include "sol_old.inc"
#include "sol_new.inc"
#include "eclipse_v5_features.hpp"
namespace g {
static const int dirs[4][2]={{1,0},{0,1},{1,1},{1,-1}};
inline bool inside(int r,int c){return (unsigned)r<15&&(unsigned)c<15;}
const char* modelname[4]={"astra_old_254","astra_new_314","sol_old_120","sol_new_160"};
inline double tree_score(const double *x,const Node*ns,const int*roots,int n){
 double s=0;for(int k=0;k<n;++k){int ix=roots[k];while(ns[ix].feature>=0){const auto &a=ns[ix];ix=x[a.feature]<=a.threshold?a.left:a.right;}s+=ns[ix].value;}return s;
}
inline double modelscore(const Board &b,int sq,int side,int mod){
 auto x=eclipse_v5_shared::features(b,sq,side);
 switch(mod){
 case 0:return tree_score(x.data(),astra_old::nodes,astra_old::roots,254);
 case 1:return tree_score(x.data(),astra_new::nodes,astra_new::roots,314);
 case 2:return tree_score(x.data(),sol_old::nodes,sol_old::roots,120);
 default:return tree_score(x.data(),sol_new::nodes,sol_new::roots,160);
 }
}
int win_at(const Board& b,int sq,int side){
 int r=sq/15,c=sq%15; for(auto &d:dirs){int ct=1;
 for(int s:{-1,1}){int nr=r+s*d[0],nc=c+s*d[1];while(inside(nr,nc)&&b[nr*15+nc]==side){ct++;nr+=s*d[0];nc+=s*d[1];}}
 if(ct>=5)return 1;}return 0;
}
bool completes(const Board&b,int sq,int side){
 if(b[sq])return false;int r=sq/15,c=sq%15;for(auto&d:dirs){int ct=1;
 for(int s:{-1,1}){int nr=r+s*d[0],nc=c+s*d[1];while(inside(nr,nc)&&b[nr*15+nc]==side){++ct;nr+=s*d[0];nc+=s*d[1];}}
 if(ct>=5)return true;}return false;
}
std::vector<int> moves(const Board&b){
 bool visited[225]={};int stones=0;
 for(int i=0;i<225;++i)if(b[i]){stones++;int r=i/15,c=i%15;
 for(int dr=-2;dr<=2;++dr)for(int dc=-2;dc<=2;++dc){int rr=r+dr,cc=c+dc;
 if(inside(rr,cc)&&!b[rr*15+cc])visited[rr*15+cc]=true;}}
 if(stones==0)return {112};
 std::vector<int>out;for(int i=0;i<225;++i)if(visited[i])out.push_back(i);return out;
}
int evaluate(const Board&b,int side){
 // Deterministic, symmetric handcrafted static evaluation shared by all four candidates.
 int scores[3]={};constexpr int weight[]={0,2,18,400,20000,300000};
 for(auto &d:dirs)for(int r=0;r<15;++r)for(int c=0;c<15;++c){int er=r+4*d[0],ec=c+4*d[1];if(!inside(er,ec))continue;
 int a=0,z=0;for(int k=0;k<5;++k){int v=b[(r+k*d[0])*15+c+k*d[1]];a+=(v==1);z+=(v==2);}
 if(a&&z)continue;if(a)scores[1]+=weight[a];else if(z)scores[2]+=weight[z];}
 return std::clamp(scores[side]-scores[3-side],-500000,500000);
}
struct Search{
 Board board{};int model=0, budget=0, visited=0, completed=0, aborts=0;
 Clock::time_point start,limit;
 bool expired(){return Clock::now()>=limit || visited>=400000;}
 std::vector<int> sorted(int side,int width){
  std::vector<int> c=moves(board);
  // Mandatory tactical gates outrank learned ordering, as in the real design.
  std::vector<int> own;for(int m:c)if(completes(board,m,side))own.push_back(m);
  if(!own.empty())return {own[0]};
  std::vector<int> defense;for(int m:c)if(completes(board,m,3-side))defense.push_back(m);
  if(!defense.empty())return defense;
  std::vector<std::pair<double,int>>ranked;ranked.reserve(c.size());
  for(int m:c){ranked.push_back({modelscore(board,m,side,model),m});}
  std::stable_sort(ranked.begin(),ranked.end(),[](auto&a,auto&b){return a.first==b.first?a.second<b.second:a.first>b.first;});
  std::vector<int>out;for(auto&v:ranked){out.push_back(v.second);if((int)out.size()==width)break;}return out;
 }
 int negamax(int side,int depth,int alpha,int beta,int ply,bool &stopped){
  ++visited;if((visited&31)==0&&expired()){stopped=true;return 0;}
  if(depth<=0)return evaluate(board,side);
  std::vector<int> cand=moves(board);
  for(int m:cand)if(completes(board,m,side))return 300000-ply;
  for(int m:cand)if(completes(board,m,3-side)){
    // Mandatory block; multiple immediate winning squares = almost certainly forced loss.
    if(std::count_if(cand.begin(),cand.end(),[&](int t){return completes(board,t,3-side);})>1)return -290000+ply;
    cand={m};break;
  }
  if(cand.size()>1)cand=sorted(side,depth>=3?5:depth==2?5:6);
  int best=-100000000;
  for(int m:cand){if(expired()){stopped=true;break;}
   board[m]=side;
   int v=win_at(board,m,side)?300000-ply:-negamax(3-side,depth-1,-beta,-alpha,ply+1,stopped);
   board[m]=0;
   if(stopped)return 0;
   best=std::max(best,v);alpha=std::max(alpha,v);if(alpha>=beta)break;
  }
  return best==-100000000?evaluate(board,side):best;
 }
 struct Decision{int move;int elapsed;int nodes;int depth;bool cutoff;};
 Decision choose(const Board&b,int side,int mod,int ms){
   board=b;model=mod;budget=ms;start=Clock::now();limit=start+std::chrono::milliseconds(ms);visited=0;completed=0;aborts=0;
   auto roots=moves(board);int fallback=roots.front();
   if(roots.size()==1)return {fallback,0,1,0,false};
   for(int m:roots)if(completes(board,m,side))return {m,0,1,0,false};
   std::vector<int>blocks;for(int m:roots)if(completes(board,m,3-side))blocks.push_back(m);
   if(!blocks.empty())return {blocks.front(),0,1,0,false};
   auto ranked=sorted(side,8);fallback=ranked.front();int incumbent=fallback;
   bool cutoff=false;
   for(int depth=1;depth<=5;++depth){
     if(expired()){cutoff=true;break;}int best=-100000000,move=incumbent;bool stopped=false;
     for(int m:ranked){++visited;
       if(expired()){stopped=true;break;}
       board[m]=side;
       int v=win_at(board,m,side)?300000:-negamax(3-side,depth-1,-100000000,100000000,1,stopped);
       board[m]=0;
       if(stopped)break;
       if(v>best){best=v;move=m;}
     }
     if(stopped){cutoff=true;break;}
     incumbent=move;completed=depth;
     if(best>=200000)break;
   }
   int elapsed=(int)std::chrono::duration_cast<std::chrono::milliseconds>(Clock::now()-start).count();
   return {incumbent,elapsed,visited,completed,cutoff};
 }
};
int main(int argc,char**argv){
  int pairs=3,ms=120,which=0,seed=201;
  for(int i=1;i<argc;i++){std::string a=argv[i];if(a=="--pairs"&&i+1<argc)pairs=std::atoi(argv[++i]);else if(a=="--ms"&&i+1<argc)ms=std::atoi(argv[++i]);else if(a=="--match"&&i+1<argc)which=std::atoi(argv[++i]);else if(a=="--seed"&&i+1<argc)seed=std::atoi(argv[++i]);}
  if(pairs<1||pairs>100||ms<1||ms>20000||which<0||which>2)return 2;
  int A=which==0?1:which==1?3:1, B=which==0?0:which==1?2:3;
  std::cout<<"{\"type\":\"config\",\"engine\":\"locally-built matched-research-search-NOT-R15-Swift\",\"A\":\""<<modelname[A]<<"\",\"B\":\""<<modelname[B]<<"\",\"budget_ms\":"<<ms<<",\"pairs\":"<<pairs<<"}\n"<<std::flush;
  Search s;int winsA=0,winsB=0,draws=0;
  for(int pair=0;pair<pairs;++pair){
    std::mt19937 rng(seed+pair*7919);std::vector<int> response;
    int first=112+(pair%5-2)*15+((pair/5)%5-2);
    for(int d=0;d<225;++d)if(d!=first&&std::abs(d/15-first/15)<=2&&std::abs(d%15-first%15)<=2)response.push_back(d);
    std::shuffle(response.begin(),response.end(),rng);int second=response.front();
    for(int flip=0;flip<2;++flip){Board b{};b[first]=1;b[second]=2;
      std::vector<int>hist={first,second};int winner=0,totalNodes[2]={},totalTime[2]={},sumDepth[2]={},cutoff[2]={},movecount[2]={};
      for(int ply=2;ply<225;++ply){int side=1+(ply%2);int who=(side==1)==(flip==0)?0:1;int model=who==0?A:B;
       auto d=s.choose(b,side,model,ms);if(d.move<0||d.move>=225||b[d.move]){std::cerr<<"ILLEGAL MOVE\n";return 3;}
       b[d.move]=side;hist.push_back(d.move);totalNodes[who]+=d.nodes;totalTime[who]+=d.elapsed;sumDepth[who]+=d.depth;cutoff[who]+=d.cutoff;movecount[who]++;
       if(win_at(b,d.move,side)){winner=who==0?1:2;break;}
      }
      winsA+=(winner==1);winsB+=(winner==2);draws+=(winner==0);
      std::cout<<"{\"type\":\"game\",\"pair\":"<<pair<<",\"A_black\":"<<(flip==0?"true":"false")<<",\"winner\":\""<<(winner==1?"A":winner==2?"B":"draw")<<"\",\"plies\":"<<hist.size()<<",\"opening\":["<<first<<","<<second<<"],\"nodes_A\":"<<totalNodes[0]<<",\"nodes_B\":"<<totalNodes[1]<<",\"ms_A\":"<<totalTime[0]<<",\"ms_B\":"<<totalTime[1]<<",\"avg_depth_A\":"<<(double)sumDepth[0]/std::max(1,movecount[0])<<",\"avg_depth_B\":"<<(double)sumDepth[1]/std::max(1,movecount[1])<<",\"timeouts_A\":"<<cutoff[0]<<",\"timeouts_B\":"<<cutoff[1]<<",\"moves\":[";
      for(size_t i=0;i<hist.size();i++)std::cout<<(i?",":"")<<hist[i];
      std::cout<<"]}\n"<<std::flush;
    }
  }
  int N=2*pairs;std::cout<<"{\"type\":\"summary\",\"games\":"<<N<<",\"A_wins\":"<<winsA<<",\"B_wins\":"<<winsB<<",\"draws\":"<<draws<<",\"A_score\":"<<std::fixed<<std::setprecision(5)<<(winsA+.5*draws)/N<<"}\n";
  return 0;
}
}
int main(int argc,char**argv){return g::main(argc,argv);}
