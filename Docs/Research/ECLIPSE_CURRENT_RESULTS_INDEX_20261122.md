# ECLIPSE · 最新成果上传与集成索引（2026-11-22）

> 面向 Gomoku Owner 的 GitHub 可追溯清单。**已上传/已编译/已合并/已发布是四个不同状态。**

## 2026-11-22 · 版本状态补记（取代下方历史 Draft 快照的当前状态）

- **Gomoku 应用：V2.0.0 / Build 200**；[整合 PR #62](https://github.com/Righteous1776/Gomoku/pull/62) 已真实合并到 `main`，合并提交 `d85d505e5da796c0807a5c5eabb0ed22649470a2`。
- **新模型：ECLIPSE 3.0**；R07 五份 34D 森林作为单独**研究代际**，身份/原始 SHA/未晋级门禁见 [PR #63](https://github.com/Righteous1776/Gomoku/pull/63)。不能把其研究代际与 V9 Astra/Sol 2.0 的当前真实执行身份混淆。
- R07 研究权重 [PR #61](https://github.com/Righteous1776/Gomoku/pull/61) 已作为 #62 合并历史中的第二父提交（`9d0dfdb65725afe39faa92239e83ab1300d48fbf`）纳入主线；**合并权重不等于 34D 已在 iOS 加载**。
- 下表是 **2026-11-22 早些时间的历史 PR 检查快照**；其中“Draft / 非 main”指当时状态，不是目前仓库的最新状态。正式 `v2.0.0` GitHub Release 与签名能力必须单独检查；不能因为代码合并就宣称 IPA 已发布。

## 工程源码：均已有 GitHub 分支及 PR

| 流程 | GitHub 入口 | 最新检查（按各自固定 HEAD） | 集成状态 |
|---|---|---|---|
| V9 2.0 模型绑定 | [#48](https://github.com/Righteous1776/Gomoku/pull/48) | 既有审核链；勿冒用选中模型身份 | Draft / 非 main |
| VeilLink 原版 Gomoku UI | [#49](https://github.com/Righteous1776/Gomoku/pull/49) | 原版交互与布局约束 | Draft / 非 main |
| Thinking HUD Stage A–C2 / D1 | [#51–#55](https://github.com/Righteous1776/Gomoku/pulls?q=is%3Apr+is%3Aopen+Thinking+HUD) | 多阶段前置依赖 | Draft / 非 main |
| PV 回放 Stage C3 | [#57](https://github.com/Righteous1776/Gomoku/pull/57) | 固定 `120c7ee8` 的 12 项 GitHub 检查均成功 | Draft / 非 main |
| 独立教学分析 Stage C4 | [#58](https://github.com/Righteous1776/Gomoku/pull/58) | 在其独立基座检查 | Draft / 非 main |
| 自适应搜索 R24 | [#59](https://github.com/Righteous1776/Gomoku/pull/59) | 固定 `a4885290` 的 12 项检查均成功，CTest 12/12 | Draft / 非 main |
| 自适应搜索 V3（独立方案） | [#60](https://github.com/Righteous1776/Gomoku/pull/60) | 固定 `8215a1eb` 的 12 项检查均成功 | Draft / 非 main |

**合并冲突说明**：#59 采用在原 V2 adaptive 模式内进行低风险早停、不设置新时间上限；#60 引入 V3 独立 ABI，并给清晰 / 普通 / 战术局面不同阶段性时间上限。二者使用了不同 HUD C3/C4 分支，不能因都获得 CI 绿色就宣称互相等价或直接合并。应由工程集成审查选择一条基线，交叉移植必要测试与真实防守保护，再做完整对弈与真机 P95。

## 训练研究：本次新上传的公开证据

- [R01–R07 聚合训练审计](./ECLIPSE_TRAINING_R01_R07_PUBLIC_AUDIT.md)
- [R07 公共机器可读指标](../../Training/research/r07_public_metrics.json)
- [R07 聚合指标一致性测试](../../Training/tests/test_r07_public_evidence.py)
- [R07 实际研究代码快照（34D 特征、续训、配对研究对抗）](../../Training/research/r07/README.md)

**模型权重已按 Owner 后续明确要求公开**：现有 7 个原始 LightGBM 模型（R04 26D 基座、R04 34D 兼容基座、R07 五个检查点）全部进入 [`Training/research/r07/checkpoints/`](../../Training/research/r07/checkpoints/README.md)，合计 4,166,924 字节，各自 SHA-256 与 Git Blob SHA 经核对。它们源自私人真人棋谱训练，公开权重仍有理论上的训练数据记忆风险；原始个人棋谱、私人测试题及 SQLite **没有**上传。权重是公开研究资产，仍**没有**绑定到现役 V9 原生引擎，也没有通过正式晋级门禁。

## 变更验收规则

1. **公开记录**：查 GitHub 具体 HEAD、PR diff 与 SHA；仅报告可核实的测试结果。
2. **模型真实加载**：设备上加载的 checkpoint SHA、策略 SHA、特征 ABI 和实际执行后端必须一致；不能只看 HUD 选择器。
3. **战术安全**：完整防守/杀棋回归，失败局面附规则合法回放，不用静态 Top-1 代替正式棋力。
4. **计算价值**：同机、相同权重、配对开局交换先后，比较耗时 P50/P95、节点数量、终止原因、棋力净收益与区间。
5. **隐私及发布**：原始 `.vltrain`、私人 SQLite、可能识别个人的原始谱局均不入公开 Git；Draft 合并和签名 IPA 由 Owner 负责验收。

## GitHub 代码状态与训练状态的区别

截至此清单生成时间，各功能**已上传到功能分支**，其 CI 通过不等于已经部署到 app。训练成果已经归档为可追踪的公开数值记录；没有经过正式原生引擎对抗、模型注册和终端部署的 R07 不得自动宣称是当前 Astra。

最新代码与报告都应从这些 PR / 固定 SHA 开始审查，禁止将多个未合并分支当作同一份已发布软件。
