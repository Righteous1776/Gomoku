# ECLIPSE · V9 Astra / Sol · GitHub 研究源码与模型交接

> **状态：30/30 份解压原始文件已上传 GitHub，2,897,781 字节，四份真实模型权重在内。**
>
> Owner 明确要求直接上传独立文件，不需要将 ZIP 上传到 GitHub。所有原始文件均保存在 [source/](source/) 目录，文件字节对应的 Git Blob SHA-1 与本地原件逐项一致。原始 ZIP 仅供个人离线归档，GitHub 未上传 ZIP 本身。
>
> **公开性质：** 当前 Gomoku 是 PUBLIC 仓库，feature/Draft PR 内的模型权重也对公众可见。此次上传不包括原始私人 .vltrain 或 SQLite；source/ 中的旧审计清单是上传前冻结的历史快照，仍可能标注 PRIVATE/NOT UPLOADED，不代表当前 GitHub 上传状态。以本文件及 artifact-receipt.json 为准。
>
> **原始 ZIP：** `ECLIPSE-V9-Astra-Sol-Handoff-20261121.zip` · 944,903 B · SHA-256 `1e277033bab96fc8a86f5385b47a27773151553a65282064069a55432f8034df`（ZIP 未上传，非集成必需）

## Owner 正式产品命名（只批准名称，不代表放行生产）

**ECLIPSE 1.0 Astra** 与 **ECLIPSE 1.0 Sol**。两者的**产品世代号完全一致：1.0**，各自有独立的训练权重、SHA-256 和推理/棋力记录。Sol 是 Astra 同代监督蒸馏的轻量模型，并非把同一模型的算力预算减半。

`V9` 是这组检查点的**内部训练迭代版本**，不等于对用户展示的 9.0，也不构成自动升级至 1.1。主应用的 `EclipseModelCatalog.swift` 已预留 `eclipse-1.0-astra` 和 `eclipse-1.0-sol` 两个独立身份及 `1.0 Astra / 1.0 Sol` 用户可见名称；本轮绑定真实 V9 源文件的身份证明记录在 `product-identity.json`。

**状态仍为命名批准 / 模型未上线。** Astra V9 必防排序 249/250 的退化未修复；Sol 的 160 树已独立保存，但真机与原训练态 Swift 天元 6× 对照未完成。生产 V2 运行时必须证明实际加载对应模型哈希，绝不能因为名称一致就假称部署成功。

## 双模型研究工件（已上传至 source/models/）

| 工件 | 26维 LightGBM 树数 | 原始权重大小 | SHA-256 |
|---|---:|---:|---|
| V9 Astra | 314 | 691,578 B | `d50190d02bf6ebd6f447d84a2920184964ac9cff1dcc0712b0076cec326a177d` |
| V9 Sol | 160 | 261,150 B | `074140fa99d52143ce3b887a553f1f11586973096baaada6476f97004e4b4fdd` |
| V8 Astra 研究基线 | 254 | 595,365 B | `44c1efcc2e35cd0dd264bda654e58b188ee0fe7a8de8f30fe45aaff9d7903685` |
| V8 Sol 研究基线 | 120 | 203,166 B | `3f31c7eca7b2b8b61997844a53eccb495daa3403e60356a5f581a9491d79d27d` |

## 可核验的研究事实

- 新旧 Astra：4 配对开局、8 局、交换黑白，V9 **5:3** V8。
- 新旧 Sol：8 局，V9 **5:3** V8。
- 同代 Astra/Sol：8 局，**4:4**。
- 共 24 局来自**独立研究 C++ 搜索器**、120ms 单步安全截止，不是 R19 正式 C ABI V2，也不是 VeilLink 训练态天元 6×。不能用来宣称统计显著的棋力优势。
- V9 Astra 发生 **唯一必防排序 249/250 对旧版 250/250** 的单题退化；按现有严格训练门禁，正式晋级 **BLOCKED**。
- Sol checkpoint 的磁盘大小比 Astra 少 62.24%；iOS 真机内存节省尚未测量。

## 与当前 R19 的集成接口

R19 统一集成 PR #43 已合并到 `main`，合并提交 `95ecd87197bdd0ec2170ad4b415fde2d14244034`。正式集成需要：

1. 从本分支 `source/models/` 获取 Astra/Sol 权重并对照 `source/SHA256SUMS.txt` 校验；无需下载 ZIP。
2. 在获授权的隔离环境执行 `source/tools/verify_bundle.py`，检查全部文件哈希与 24 局合法落子。
3. 在 R19 真实 C++ 搜索评分器中装载对应 LightGBM 权重，再由 `eg_active_trained_checkpoint_sha256_v2` 基于**已实际加载模型**出具正确哈希。现有返回 0 表示尚未装载，不能伪装。
4. Sol 为同代轻量候补模型；不得在用户不知情时直接切换、污染签名对局的模型归属。
5. 保持原有强制胜防、真机/XCTest/搜索中断与 Swift 原版训练态天元 6× 对照的阻断门槛。

## 未完成项

- [x] GitHub 已接收 **30 份解压源文件**；原始 ZIP 不上传，因为 Owner 明确要求仓库直接保存独立文件。
- [x] 上传前检查包内文件：无原始私人 .vltrain/SQLite；**模型研究权重已公开**。仍应评估潜在训练数据反推风险，不宜将未经审计的新增私有文件放入本目录。
- [ ] 将权重实际集成 R19，跑真实双引擎对抗并通过必防排序零退化门。
- [ ] 设备资源、iOS Release、真实训练态天元 6× 棋力验收。
- [ ] Owner 最终批准正式型号发布；节点 C 未启动。

**本目录已包含研究权重和合成对局证据，但不包含原始私人棋谱。研究文件已上传 ≠ R19 真实模型已加载 ≠ 正式产品发布。**
