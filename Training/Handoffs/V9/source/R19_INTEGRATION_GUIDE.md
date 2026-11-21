# R19 迭代 Agent 接线清单 — V9 Astra / Sol

**对接的最新集成入口：** https://github.com/Righteous1776/Gomoku/pull/43 ，来源 head `b3106ca2f281a7e97414cc9720dbef4f22ce6bf9`（创建包时检查）。旧 R15 PR #38 是架构继承，不是最新接线目标。**此文档只交接研究工件，不自动修改 GitHub 或软件。**

## R19 实际执行契约

- iOS 的 `EclipseCppProductionAdapter.swift` 调用 `eg_analyze_compute_policy_v2`；`EclipseTrainerProductionRegistry` 仅在型号、R 系训练修订、checkpoint SHA、计算策略 SHA 与**当前 C++ 实际加载**的 checkpoint 匹配时允许 C++ 新模型执行。
- `eg_active_trained_checkpoint_sha256_v2` 在 R19 GitHub 快照仍**返回 0**，表示模型加载证据缺失；不得将本包 manifest 的文本哈希写成假回执。
- `ECLIPSE_ACTIVE_MODEL.json` 是严格生产绑定文件，**本包未生成该文件**：产品正式模型 ID/训练 R 修订尚未获批，模型权重尚未接到真正 R19 搜索评分器，算力配置尚未经真机测量。不能只复制研究模型名 `V9` 冒充 `eclipse-1.1-astra` 等产品版本。
- 交接模型为 **26 维 LightGBM 候选排序器**。`research_engine` 有实跑 24 局的可复现 C++ 搜索源码，但**不是** R19 的 C ABI V2。集成 Agent 需将权重真实接入 R19 `Engine/src/eclipse_trained_ordering.hpp` 中的评分支路，保持强制战术门和旧 R10 路径可回滚。
- R19 现有单一 checkpoint 身份 API 只能表明**当前 active 模型**；Sol/Astra 同时可用需要独立加载身份与型号切换流程，或未来扩展不破坏 V2 的兼容接口。不得缓存 Astra 哈希后偷换 Sol 的评分树。

## 计算策略：训练 Agent 的两份研究提案

| V9 候选 | 硬安全时限 | 节点安全上限 | 深度 | 根候选 | 应手 | 后续 | 强迫线 | 半径 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| Astra | 30,000ms | 1,200,000 | 12 | 24 | 16 | 8 | 8 | 3 |
| Sol | 8,000ms | 400,000 | 9 | 16 | 10 | 6 | 6 | 2 |

这是下一阶段**待真机、战术与延迟 A/B 验收的试验上限**，不是建议每步用满或已经安装的生产配置。当前 R19 架构把 `mode=adaptive` 限定为 `max_wall_time_ms=null`，因此为提供**明确硬时间安全上限**，本研究提案按现有 schema 使用 `mode=budgeted`；即使如此，搜索也应基于局面提前退出，不必等到时间墙。未来要让 adaptive 同时携带可选安全上限，须由获授权 Agent 修改 schema / Swift 和 C++ 统一验证，不能擅自用不兼容 manifest 绕过现有类型约束。

**SHA-256 规则：** 仅对 `compute_policy` 九个字段使用 JSON `sort_keys=True,separators=(',',':')` 的 UTF-8 字节计算摘要；结果已写入 `policy_candidates/*.json`，不能拿整个提案文件的哈希填生产绑定。

## 必须先过的门

1. `tools/verify_bundle.py` 和 LightGBM 真实 checkpoint 加载 / 26 维模型身份验证。
2. 修复并回归 Astra V9 `63` 与强制阻挡 `64` 的静态排序反例；不得因 24 局对战结果满意而静默放宽“零强制战术退化”治理门。
3. 真正在 R19 C++ V2 scoring 主链中使用 Astra 或 Sol 的权重，运行时给出**正确的实际 active 模型哈希**，并完成合法落子/自适应提前停止/取消/计时/回退测试。
4. 同硬件实测 Sol 的真实总内存/设备 CPU/热状态/耗时，检查不同资源触发时能否在**新对局或经授权可逐手记录的情境**使用 Sol 替代 Astra。
5. 与加载私人训练状态的 VeilLink Swift `zenith` 6× 对手做交换黑白对战，给出足够样本数和统计区间；不得把空私人训练 `GomokuBot` 参考当作真正训练态对手。
6. iOS XCTest、C++ CI、Release、设备权限/隐私、Owner 产品晋级审批，全部单独打勾；训练或压缩完成不等于生产模型生效。

**本包不含私人原始棋谱**。若需复现真正训练态 Swift 天元六倍，需要 Owner 通过私有渠道提供训练快照及授权。提交公开 PR 时只允许**抽象模型摘要、哈希、非私人合成测试**，不得上传这份包含 checkpoint 的 ZIP。
