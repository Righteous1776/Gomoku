# [AGENT-DROP] SOURCE — ECLIPSE 原版搜索源码保真提案（批次 1）
## Goal
按照 Owner 指令登记 Gomoku 原版迁移工作，将来自固定 VeilLink 提交的实际 Swift 源码形成可审查的 `git apply` 补丁。只提议放入 `Legacy/Original/`，不直接集成进 iOS、不宣称棋力迁移已经成功。

## Changes
- `PATCH.diff` 新增 **9 份** VeilLink 原版 ECLIPSE 搜索/排序/战术/阵法文件的逐行源码文本；仅在 `Legacy/Original/`，无现有产品文件修改。
- 原始来源：`Righteous1776/VeilLink@0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32`。
- 文件对应关系及 Git Blob SHA（SHA-1 对象身份，不是 SHA256）：
  - `VeilLink/Agent/Games/GomokuBot.swift` → `Legacy/Original/VeilLink/Agent/Games/GomokuBot.swift` · blob `5659c3527646ef45df5bf23503fbb6bbf6c61277` · 25491 字符
  - `VeilLink/Agent/Games/VeilGomokuUnifiedSearch.swift` → `Legacy/Original/VeilLink/Agent/Games/VeilGomokuUnifiedSearch.swift` · blob `94d9173b490159b2b9402656fa0a386ed0a59c1e` · 29230 字符
  - `VeilLink/Agent/Games/VeilGomokuUnifiedBridge.swift` → `Legacy/Original/VeilLink/Agent/Games/VeilGomokuUnifiedBridge.swift` · blob `3bddc8ec8a7c19891e703d662b434bd167fa4c1f` · 3435 字符
  - `VeilLink/Agent/Games/EclipseTrainedOrdering.swift` → `Legacy/Original/VeilLink/Agent/Games/EclipseTrainedOrdering.swift` · blob `4e73cc1910820324487d9350194cfb5562a8439f` · 153494 字符
  - `VeilLink/Agent/Games/EclipseDifficultyPolicy.swift` → `Legacy/Original/VeilLink/Agent/Games/EclipseDifficultyPolicy.swift` · blob `f1c830c4c3d57c17d2bb974e3ec1e8d12a6b85fa` · 1713 字符
  - `VeilLink/Agent/Games/EclipseHorizonQuiescenceR12.swift` → `Legacy/Original/VeilLink/Agent/Games/EclipseHorizonQuiescenceR12.swift` · blob `0eb6e94e37052a19cc2b96bc1a82463f6fadfc22` · 3384 字符
  - `VeilLink/Agent/Games/EclipseIncrementalThreatIndexR13.swift` → `Legacy/Original/VeilLink/Agent/Games/EclipseIncrementalThreatIndexR13.swift` · blob `a8241383c28422ac75542caaa7b5f684c01c39bb` · 6330 字符
  - `VeilLink/Agent/Games/GomokuCounterForkR4.swift` → `Legacy/Original/VeilLink/Agent/Games/GomokuCounterForkR4.swift` · blob `93fc11499f7a41caef25db79f7f4482c53257681` · 14924 字符
  - `VeilLink/Agent/Games/GomokuFormationLearning.swift` → `Legacy/Original/VeilLink/Agent/Games/GomokuFormationLearning.swift` · blob `2acc24f2a960a2ccc78fce962658716afa2bc83b` · 11564 字符
- 该批仅覆盖 `ai-core` 16 项中的 9 项。未包括控制器、训练、自对弈、数据归档、原版 UI/仪器主题、测试与私有数据。完整 69 项仍须根据 `Migration/source_inventory.json` 分批抽取并审计。

## Risks
- `feature/governance-lite` 的 PR #1 原提交时未合并（2026-11-20 后续检查已合入 main；但 SOURCE 仍未正式分配），`AGENT_INBOX/BOARD.json` 中 `SOURCE` 仍为 `OPEN / unassigned`。本分支 **DRAFT，等待 Owner 正式分配**；不自改 BOARD、不冒充 Governor、不可声称通过 check-drop。
- 本补丁由 GitHub 连接器读取的 UTF-8 文本生成；Git Blob SHA 已记录，但尚未对应用后的文件运行 SHA256 比对、`git apply --check`、源码编译或棋力评测。无法宣称原版引擎可编译或行为等价。
- 只有原样保留的源文件，尚未解析 `MiniGameKind`、`GomokuState` 等跨模块依赖；不得改名或立即设置为 Xcode Target 的编译源。
- 原版数据、签名密钥、聊天记录及未经核实权重不属于本提案。

## Rollback
只撤回此 Draft PR 即可，不影响 `main` 或上游 VeilLink。后续受权集成采用独立提交；若集成发现问题通过 revert 回滚，不能强推主干。

## Evidence
- 原 Gomoku 仓库 `Legacy/Original/` 只有占位文件。
- 19? 不。本批准确是 **9/16 个 ai-core 文件**；69 项上游 inventory 其中 57 critical、12 reference。
- 9 个源码读取请求实际成功；每项来源 blob 如上。Git 对象级二次比对及单元测试 **NOT RUN**。
- 产品 iOS 构建此前失败，和本次原样源码归档是不同任务。

## Next
1. 治理 PR #1 已合并；Owner 仍需在可信 main 正式分配 `SOURCE` 给 `chatgpt-source-audit`，设置 `WORKING`；本人不修改任务板。
2. 以合并后的真实 main 完整 SHA 更新分支与 TASK.json；执行 `python3 Scripts/inbox.py check-drop --base <main-sha> --head <drop-sha> --branch agent-drop/chatgpt-source-audit/SOURCE`，通过后才能标 REVIEW。
3. 集成负责人在 `integration/SOURCE` 先跑 `git apply --check`、应用后 SHA256 与原始固定提交的对照。
4. 补齐剩余 7 项 ai-core、3 项 core-rules、13 项 original-ui、8 项 instrument-theme、2 项 resource、15 项 legacy-tests，并审计 12 项参考依赖；完善 `Provenance/migrated_sources.sha256.json`，只有实测后才报告迁移完成。


## R17.2 owner-corrected UI migration addendum — 2026-11-20

### Verified source versions and authority
- The original R17.2 PR https://github.com/Righteous1776/VeilLink/pull/234 is **OPEN / NOT MERGED**; its description explicitly advertises a lower telemetry dashboard and 0.65s move impact ring. **Do not wholesale copy** its 10 FILES/ candidates or `R17_ADVISORY.patch`: they were based on an R16/PR#220 hybrid and conflict with V29.2 Build69 controller/search settings.
- Upstream `VeilLink/main@0e4b51e990ee1ab2c13c8b1b16bdb94ee8ee5f32` actually contains:
  - `VeilLink/UI/GameLobbyView.swift` displaying `VeilEclipseRuntimeInstruments(...).veilCard()` immediately under `VeilEclipseIdentityCard` around lines 428–435, the **owner-rejected lower instrument/dashboard card**.
  - `VeilLink/UI/MiniGameViews.swift` using `GomokuBoardView` state `impactIndex`, `impactScale`, impact-ring overlay and a 0.65 s `withAnimation` on `state.lastMove` around lines 1454 and 1533–1570, the **owner-rejected move landing ripple**.
- The later *isolated, not merged or released* repair branch `integration/v30-eclipse-r17-selective-20261120@af37b1e90ef77fc0ca0bb176a96d6a43bb234a1d` contains `docs/engineering/V30_ECLIPSE_R17_TRIAGE.md`, documenting the owner's rejection and verified selective replacement:
  - `VeilLink/UI/GameLobbyView.swift` lacks the standalone `VeilEclipseRuntimeInstruments(` call (source blob `6895008140ae664a5720ed758ed831858a46b351`).
  - `VeilLink/UI/MiniGameViews.swift` has no `impactIndex` / `impactScale` / `impactExpanded` state or landing ring; keeps ordinary last-move highlight and search thought-field (blob `eed723bfc8f779ac772de31781301a15c5fad7c4`).
  - `VeilLink/UI/VeilEclipseComputeConsole.swift` displays truthful `REAL CLOCK  T+` from `actualSearchStartedAt` with low-cost `TimelineView` updates, no synthetic fast terminal stream and no standalone new dashboard (blob `2e33f053f458fca37ced6bdb5f5b702d117b5105`).
  - `scripts/verify-v30-eclipse-owner-regressions.py` statically guards absent card/ripple plus preserved strength slider and no-time-limit toggle (blob `26236d3f9cd070b37b263be46de2863bc482d522`).
- None of this selective integration is verified as merged into the VeilLink main, verified by full Xcode build, or present in standalone Gomoku; do not claim feature migration complete.

### Binding requirements for Gomoku IOS lane
1. **DO NOT PORT:** `VeilEclipseRuntimeInstruments` as a lower standalone card, any extra four-stat dashboard block, `GomokuBoardView.impactIndex`, `impactScale`, `impactExpanded`, expanding board lock ring/landing ripple, decorative fake node counters/LEDs or periodic cosmetic terminal scroll.
2. **MUST PORT:** Original `instrumentAuto` visual palette, 15x15 warm-brown board, upper black robot `VeilEclipseIdentityCard` and `VeilEclipseComputeConsole`, truthful in-console stopwatch and measured search evidence, original touch semantics (no drag interception), seven difficulties including 2x/4x/6x search-budget multipliers.
3. **MUST PRESERVE:** V29.2 Build69 1–10 thinking-strength slider, user-controlled unlimited-thinking/no time cutoff, finite node/depth safety, search cancellation; independently audit which features exist in each available source revision before adaptation.
4. **DIFFERENTIATE:** Existing `state.lastMove` nonanimated highlight and optional validated search thought-field are **not** the rejected expanding ripple. Do not delete basic move indication or legitimate analysis.
5. **NO VERSION COLLISION:** Keep `Legacy/Original/` byte-identical to pinned source. Any corrected R17.2 implementation belongs in a separately provenance-mapped adapted UI implementation after OWNER assignment of IOS and integration review; never overwrite the original source with a repaired variant or silently update source pin.

### Required IOS acceptance evidence
- Static negative tests: no `VeilEclipseRuntimeInstruments(` in game screen, no `impactIndex`, `impactScale`, `impactExpanded`, no expanding landing ring; prevent reintroduction in UI integration.
- Positive tests: upper ECLIPSE panel remains, clock reflects actual start time (not estimated computation progress), 1–10 strength/unlimited time settings and 7 tiers remain.
- Run `xcodebuild` and manual iPhone/iPad UI check for the genuine theme, no touch interception, Reduce Motion/Low Power performance; **NOT RUN** for this Inbox report.
- Propose separate source-fidelity and IOS UI steps when task ownership and SOURCE dependency are settled; the present SOURCE drop is **not** the IOS lane and does not modify product UI.
