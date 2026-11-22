# ECLIPSE R26 — Verified full-game research outcomes · 2026-11-22

**Status: measured exploratory evidence; NEVER a formal Elo, strength parity or model promotion.**
All games were executed by actual native engines in GitHub Actions on Ubuntu 24.04, using the exact source and model SHA pins. These JSONL logs were copied verbatim from successful GitHub Actions jobs after independent move-by-move win/legality/terminal replay, not generated or modeled from predictions.

## 1. Actual original VeilLink Tianyuan 6x vs R25-273

- Workflow: [R26 original Swift Zenith job](https://github.com/Righteous1776/Gomoku/actions/runs/44987544499), [original full-game artifact](https://github.com/Righteous1776/Gomoku/actions/runs/44987544499/artifacts/14740915002).
- Both sides: **5,700ms per-move ceiling**, **30,000-node search ceiling**, **depth cap 7**. The Swift and C++ search algorithms, threat preflights and candidate scoring differ. *Equal policy ceilings are not equal observed compute.*
- Pair: the same initial two moves `[112,97]`, **2 completed full games with reversed colors**. R25 played as black and won after **31 plies**; original Swift Zenith played as black and won after **41 plies**.
- Result: **R25 1W / 1L / 0D, exploratory score 50.0%**; BOTH wins were for black, so color advantage/limited opening coverage make any dominance or parity claim unjustified.
- Total **measured native search elapsed** across the two games: R25 **35,072ms**, original Swift Zenith **12,647ms**. Each completed **34 engine decisions** (excluding initial fixed opening), yielding R25 **1,031.53ms/move** and Zenith **371.97ms/move**. The R25 engine consumed **2.77×** as much search wall time per decision despite the identical upper ceiling. C++ weight loading process startup is recorded separately in the JSONL. These are Ubuntu runner measurements, not mobile-device P95/energy measurements.
- Original teacher Swift `GomokuBot.swift` source SHA-256: `3ae1eecd1bf321c79365e868be5b45f1ea08c06e3657746127a173d1e72c6cb2`. Personal learning is disabled; no owner's history was used.

Raw: [r26-r25-vs-original-zenith6x-5700ms.jsonl](../../Arena/evidence/r26-r25-vs-original-zenith6x-5700ms.jsonl)

## 2. Fairer same-search weight isolation: R25-273 vs R07-249

- Workflow: [R26 native same-engine job](https://github.com/Righteous1776/Gomoku/actions/runs/44987544499), [JSONL artifact](https://github.com/Righteous1776/Gomoku/actions/runs/44987544499/artifacts/14740337552).
- Both contestants use byte-identical **native C++ PVS/VCF**, feature extraction and time/width/forcing policy. Only the **actual forest weight** changes. Both are SHA-attested and loaded on every game.
- 2 synthetic opening families, each run with black/white swapped, 4 completed games per setting. Full separate budgets, DO NOT collapse them into a single benchmark with one effective search depth.

| Setting (each contender same C++ policy) | R25 win | R07 win | Draw | R25 score |
|---|---:|---:|---:|---:|
| 150ms ceiling / depth 3 | **1** | **3** | 0 | **25%** |
| 300ms ceiling / depth 5 | **3** | **1** | 0 | **75%** |

The reversal between 150ms and 300ms could reflect model-ordering × search-depth interaction, but four games in either cohort cannot distinguish it from opening variance. This is **not evidence of a reliable improvement** or of a predictable cost-performance crossover.

Raw: [150ms games](../../Arena/evidence/r26-r25-r07-150ms-games.jsonl) and [300ms games](../../Arena/evidence/r26-r25-r07-300ms-games.jsonl).

## 3. Actual verified artifacts and limits

- R07 model **249 trees / 34D** SHA-256: `d4cea7f62e9e8ffc119d60861ce05df43aafdbdc280b51707dc1b7e40e5fc234`.
- R25 model **273 trees / 34D** SHA-256: `bc9b1aabb6ae00de22e77943f5bd8c35ecff1b490e2ea74d5b10609b876f428d`.
- CI [core](https://github.com/Righteous1776/Gomoku/pull/68) executed **14/14 CTest**, including real native R25 load/SHA guard, exact 34D fixture, legal search, forced win, forced block and model-identity isolation.
- Each JSONL is independently validated by its companion `Engine/tests/validate_r25_*.py` script. Correct final outcomes, complete legal move sequences, matched side swaps, source identities and policy fields are checked.
- R25's previous independent teacher imitation holdout remained **21/42 Top-1**, same as pre-distillation R07. Therefore the model remains research-only.

**P0 decisions:** Do not promote R25, replace production Astra, rename model versions or claim superiority over Tianyuan. More diverse independent paired openings, at least hundreds of complete games per meaningful budget, uncertainty intervals, forced-tactics regression, heldout features parity, comparable device P50/P95 and thermal tests are necessary.

