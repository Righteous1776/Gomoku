# ECLIPSE V9 — Astra + Sol 双模型私有交接包

**状态：可供迭代 Agent 技术预审，不是正式可发布模型。** 内部版本 **V9**；正式命名、产品版本号和节点 C 不由训练 Agent 自行决定。

## 最新迭代分支与 R19 接线

最新的总集成目标是 **[R19 PR #43](https://github.com/Righteous1776/Gomoku/pull/43)**，不是旧 R15 单独分支。阅读 `R19_INTEGRATION_GUIDE.md` 和 `policy_candidates/*.json`：提供具体的 Astra/Sol 算力上限研究提案、精确 policy SHA-256 与 C ABI V2 接线门槛；**还不能生成生产绑定或声称模型已在 C++ V2 实际加载**。

## 这次封装的是实际训练权重，不是占位文件

| 内部研究工件 | LightGBM 树 | 文件体积 | 研究验收定位 |
|---|---:|---:|---|
| Astra V9 | 314 | 691,578 B | **实验旗舰**，必防排序层退化，阻断正式晋级 |
| Sol V9 | 160 | 261,150 B | **本代蒸馏模型**，候选资源不足降级路径 |
| Astra V8 | 254 | 595,365 B | 当前旧安全排序研究基线 |
| Sol V8 | 120 | 203,166 B | 旧研究基线 |

相对 V9 Astra，Sol 的**磁盘权重文件减小 62.24%**。这不是 iPhone 实际内存降低 62.24% 的证明；需测量加载后的内存峰值、总搜索节点、耗时、温度与电耗。

## 实际研究对局证据（共 24 局，非原版天元 6×）

- V9 Astra 314 对 V8 Astra 254：**5:3**。
- V9 Sol 160 对 V8 Sol 120：**5:3**。
- 同代 V9 Astra 对 V9 Sol：**4:4**；该组 Astra 26 次搜索中断，Sol 0 次；双方**同为 120ms 单步硬上限**。
- 每组 8 局、4 个开局交换先后手。样本不足以宣称跨代显著更强，或推断 Sol 强于/弱于 Astra 的总体棋力。
- **与原版 VeilLink 已训练 Swift 天元 6×：0 局。** 不得据此宣称追平。

## 已知阻断：不能因满意小样本比分而抹掉

完全合成的唯一防守局面，黑棋 `[10,79,95,111]`，白棋 `[4,19,34,49]`，黑方唯一必防索引 `64`。Astra V8 254 树排序第一为 64，V9 314 树却排序第一为 63，正确点降至第三（249/250 vs 250/250）。这是**排序层**退化，不代表带规则硬门的正式搜索器真的漏防，但在训练零退化门槛中仍标 **BLOCKED**。Sol 同类简化排序也有旧缺陷，必须依赖强制规则门并单独复测。

## 给迭代 Agent 的验收与接线顺序

1. 私有位置接收 ZIP，先执行 `python3 tools/verify_bundle.py` 复核所有工件哈希和实际局记录。
2. 在装有 `lightgbm>=4.6`、`numpy` 的本地环境，运行 `python3 tools/model_probe.py --model astra-v9 --identity` 与 `--model sol-v9 --identity`。该工具**真实加载 checkpoint** 并验证 SHA，但它不是符合 R15 `--best` 的生产搜索运行器；严禁把 probe 的验证当成通过 R15 升级门。
3. 先在隔离分支中接入研究 C++20 核心（`research_engine/` 只作可复现研究对照），再由获授权集成 Agent 对接原版 R15 Swift/C++ 引擎。优先修复必防排序反例并证明战术安全门没有回归。
4. 真机测量 Astra 与 Sol 的实际热/内存/耗电、每步 P50/P95/P99 时延、硬超时与自然收敛。落实降级时不得悄悄改变用户选择、棋谱模型来源或对局归档签名。
5. 按相同规则和可比资源进行已训练原 Swift 天元 6× 配对交换颜色对局。真实训练态数据本包未收录；**不可用空个人学习的 Swift 替代来宣称完成认证**。
6. R15 strict handoff schema (`eclipse.trainer.handoff.v1`) 所需的 R 系修订、拟议正式代际、独立来源哈希、真实加载的 `--best` 推理运行器等**仍未齐备**，不得伪造字段填表通过门禁。额外诊断存在 `manifest/REVIEW-MANIFEST.json`，它是独立研究级 schema，不是 R15 上线许可。

## 本包结构

- `models/`：原始四份 LightGBM 文本 checkpoint（已用 V8/V9 重命名，**字节原样保存**）。
- `manifest/REVIEW-MANIFEST.json`：研究级审计快照、真实 SHA-256、状态与阻断项。
- `evidence/`：24 局逐局记录、验证器、唯一必防反例和聚合训练报告；不含原始私人用户棋谱。
- `research_engine/`：此前实际执行 24 局的本地研究 C++20 搜索器和四份由模型导出的静态树；**不是 R15 正式 C++ 引擎**。
- `tools/`：独立验签和 LightGBM 实际载入/静态排序探针。
- `ui/`：离线逐手回放界面。
- `SOL_FALLBACK_POLICY.md`：Sol 降级方案与 R15 现有归档兼容限制。
- `SHA256SUMS.txt`：全包文件级完整性清单（不包括清单本身）。
- `R19_INTEGRATION_GUIDE.md`、`policy_candidates/*.json`：面向最新 R19 的交接条件及 Astra/Sol 待测计算策略。

## 编译与复现

```bash
python3 tools/verify_bundle.py
python3 tools/model_probe.py --model astra-v9 --identity
python3 tools/model_probe.py --model sol-v9 --identity
python3 tools/model_probe.py --model astra-v9 --tactical-smoke
python3 tools/model_probe.py --model sol-v9 --tactical-smoke

g++ -std=c++20 -O2 -DNDEBUG research_engine/arena.cpp -o research_engine/arena
research_engine/arena --pairs 4 --ms 120 --match 2 --seed 20261121
```

研究对局采用真实时间截止，重跑不能保证每步相同；无论胜负如何，都必须保存已验证的历史观测、原版对照与上限变化。私有 ZIP **不要上传公开 GitHub/CI/Inbox**。本包制作不代表已经发送给迭代 Agent、提交到 main、发布应用或启动节点 C。
