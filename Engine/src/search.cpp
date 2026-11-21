#include "search.hpp"
#include <algorithm>
#include <limits>
#include <utility>

namespace eclipse {
namespace {
constexpr std::int64_t kInfinity=1'000'000'000LL;
constexpr int other(int p){return p==1?2:1;}
}

bool Search::out_of_time() {
    // Limit expensive clock calls; intentional bounded overrun at small node counts.
    if((++nodes_&127u)!=0)return timed_out_;
    if(Clock::now()>=deadline_)timed_out_=true;
    return timed_out_;
}

std::vector<int> Search::sorted_candidates(const Board &b,int limit) {
    auto moves=b.candidates();
    std::vector<std::pair<std::int64_t,int>> scored;
    scored.reserve(moves.size());
    for(int m:moves) {
        if(b.winning_move(m,b.turn))return {m};
        Board p=b;
        p.play(m);
        const std::int64_t score=p.evaluate(b.turn);
        scored.push_back({score,m});
    }
    std::sort(scored.begin(),scored.end(),[](auto a,auto b){return a.first==b.first?a.second<b.second:a.first>b.first;});
    moves.clear();
    for(int i=0;i<static_cast<int>(scored.size())&&i<limit;++i)moves.push_back(scored[i].second);
    return moves;
}

std::int64_t Search::negamax(const Board &b,int depth,std::int64_t alpha,std::int64_t beta) {
    if(out_of_time())return b.evaluate(b.turn);
    if(b.outcome!=0||depth<=0)return b.evaluate(b.turn);
    const auto candidates=sorted_candidates(b,depth>1?10:14);
    if(candidates.empty())return b.evaluate(b.turn);
    std::int64_t best=-kInfinity;
    for(int m:candidates) {
        Board next=b;
        next.play(m);
        const std::int64_t score=-negamax(next,depth-1,-beta,-alpha);
        best=std::max(best,score);
        alpha=std::max(alpha,score);
        if(alpha>=beta||timed_out_)break;
    }
    return best;
}

SearchResult Search::analyze(const Board &root, int milliseconds) {
    const auto started = Clock::now();
    nodes_ = 0;
    timed_out_ = false;
    auto finish = [&](int move, SearchStopReason reason, int depth) {
        SearchResult result;
        result.move = move;
        result.reason = reason;
        result.completed_depth = depth;
        result.nodes = nodes_;
        result.elapsed_ms = static_cast<int>(
            std::chrono::duration_cast<std::chrono::milliseconds>(
                Clock::now() - started).count());
        return result;
    };

    if (root.outcome != 0)
        return finish(-1, SearchStopReason::no_move, 0);
    const auto moves = root.candidates();
    if (moves.empty())
        return finish(-1, SearchStopReason::no_move, 0);
    if (moves.size() == 1)
        return finish(moves.front(), SearchStopReason::only_move, 0);

    // Preserve mandatory tactical gates, even for very small time budgets.
    for (int m : moves)
        if (root.winning_move(m, root.turn))
            return finish(m, SearchStopReason::forced_win, 0);
    std::vector<int> urgent;
    for (int m : moves)
        if (root.winning_move(m, other(root.turn)))
            urgent.push_back(m);
    if (!urgent.empty())
        return finish(*std::min_element(urgent.begin(), urgent.end()),
                      SearchStopReason::forced_block, 0);

    deadline_ = Clock::now()
        + std::chrono::milliseconds(std::clamp(milliseconds, 1, 20'000));
    auto ranked = sorted_candidates(root, 18);
    if (ranked.empty())
        return finish(-1, SearchStopReason::no_move, 0);
    int incumbent = ranked.front();
    int completed_depth = 0;
    for (int depth = 1; depth <= 4; ++depth) {
        int round_best = incumbent;
        std::int64_t round_score = -kInfinity;
        for (int m : ranked) {
            if (Clock::now() >= deadline_) {
                timed_out_ = true;
                break;
            }
            Board next = root;
            next.play(m);
            const std::int64_t score =
                -negamax(next, depth - 1, -kInfinity, kInfinity);
            if (timed_out_) break;
            if (score > round_score ||
                (score == round_score && m < round_best)) {
                round_score = score;
                round_best = m;
            }
        }
        if (timed_out_) break;
        incumbent = round_best;
        completed_depth = depth;
        if (Clock::now() >= deadline_) {
            timed_out_ = true;
            break;
        }
    }
    return finish(incumbent, timed_out_ ? SearchStopReason::time_limit
                                      : SearchStopReason::complete,
                  completed_depth);
}

int Search::best_move(const Board &root, int milliseconds) {
    return analyze(root, milliseconds).move;
}
}
