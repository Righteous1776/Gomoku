#pragma once
// V5 research-only 26-feature ABI; NOT a product release: 26 features transcribed from R8 candidate ordering interface.
// Reference: Righteous1776/Gomoku PR #31 commit ca951a3..., Engine/src/eclipse_trained_ordering.hpp.
// This is a local auditable copy, NOT an automatic patch to production.
#include <algorithm>
#include <array>
#include <cmath>
#include <cstdint>
namespace eclipse_v5_shared {
inline bool inside(int r,int c) {return r>=0&&r<15&&c>=0&&c<15;}
inline std::array<double,26> features(const std::array<std::uint8_t,225>&board,int index,int side) {
 std::array<double,26> x{};
 if(index<0||index>=225||board[index]!=0||(side!=1&&side!=2)) return x;
 constexpr int axes[4][2]={{1,0},{0,1},{1,1},{1,-1}};
 const int enemy=side==1?2:1, r=index/15,c=index%15;
 for(const auto &axis:axes){
  const int dr=axis[0],dc=axis[1];
  for(int offset=0;offset<5;++offset){
   const int rr=r-offset*dr,cc=c-offset*dc;
   if(!inside(rr,cc)||!inside(rr+4*dr,cc+4*dc))continue;
   int own=0,other=0;
   for(int k=0;k<5;++k){const int v=board[(rr+k*dr)*15+cc+k*dc];own+=(v==side);other+=(v==enemy);}
   if(!other&&own>=1&&own<=4)x[own-1]+=1;
   if(!own&&other>=1&&other<=4)x[4+other-1]+=1;
  }
 }
 int own_axes=0,enemy_axes=0;
 for(const auto &axis:axes){
  const int dr=axis[0],dc=axis[1];
  int own=1,other=1,own_open=0,other_open=0;
  for(int sign:{-1,1}){
   int rr=r+sign*dr,cc=c+sign*dc;
   while(inside(rr,cc)&&board[rr*15+cc]==side){++own;rr+=sign*dr;cc+=sign*dc;}
   if(inside(rr,cc)&&board[rr*15+cc]==0)++own_open;
   rr=r+sign*dr;cc=c+sign*dc;
   while(inside(rr,cc)&&board[rr*15+cc]==enemy){++other;rr+=sign*dr;cc+=sign*dc;}
   if(inside(rr,cc)&&board[rr*15+cc]==0)++other_open;
  }
  x[8]=std::max(x[8],static_cast<double>(own));
  x[9]=std::max(x[9],static_cast<double>(other));
  if(own>=3&&own_open==2)x[10]+=1;
  if(other>=3&&other_open==2)x[11]+=1;
  if(own>=4&&own_open>=1)x[12]+=1;
  if(other>=4&&other_open>=1)x[13]+=1;
  if(own>=3&&own_open>=1)++own_axes;
  if(other>=3&&other_open>=1)++enemy_axes;
  for(int sign:{-1,1})for(int dist=1;dist<=2;++dist){
   const int rr=r+sign*dist*dr,cc=c+sign*dist*dc;
   if(!inside(rr,cc))continue;
   const int v=board[rr*15+cc];
   if(v==side)x[dist==1?14:16]+=1;
   if(v==enemy)x[dist==1?15:17]+=1;
  }
 }
 x[18]=static_cast<double>(15-std::abs(r-7)-std::abs(c-7));
 x[19]=static_cast<double>(std::min({r,c,14-r,14-c}));
 for(int v:board)if(v!=0)x[20]+=1;
 x[21]=own_axes; x[22]=enemy_axes;
 x[23]=x[2]*(x[2]-1)/2;
 x[24]=x[6]*(x[6]-1)/2;
 x[25]=1;
 return x;
}
}
