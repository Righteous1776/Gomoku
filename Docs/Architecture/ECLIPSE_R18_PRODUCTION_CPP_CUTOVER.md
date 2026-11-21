# ECLIPSE R18 · 正式 C++ 架构启用（模型与架构分开验收）

## Owner 明确指令
正式启用 **C++20 + C ABI V2 + Swift 前端/存储**架构。模型训练由独立训练 Agent 完成；不因训练检查点尚未交接而否定架构本身。亦不得拿旧版冻结 R10 模型假冒最新 214-tree C++ 训练产物。

## 实际生产调用路径
```
InstrumentHomeView (正式应用)
  → NativeGomokuAppController.scheduleAI
    → EclipseTrainerProductionRegistry.loadFromBundle
      → ECLIPSE_ACTIVE_MODEL.json (模型 ID、训练 revision、计算策略 SHA)
      → eg_active_trained_checkpoint_sha256_v2 (真正已加载的 C++ 检查点哈希)
    → 一致：EclipseCppProductionAdapter (Release 包含)
      → EGComputePolicyV2 (训练 Agent 自主裁决，无产品层时限)
      → eg_analyze_compute_policy_v2 → C++ Search
      → 真实 move/nodes/depth/time
    → 不一致/未安装/失败：原版 Swift GomokuBot 路径，
      明确标记回退，不记作新模型的胜利
    → 现有落子合法性、棋谱、断点恢复、训练归属
```

此前仅 DEBUG 的研究桥继续用于测试，但现在 Release 的正式控制器已有 C++ 搜索入口，不再局限于研究 UI。旧版 Swift 强制战术仍作为应急后备。

## 训练 Agent 的最终交接：无需重新训练
已知训练 Agent 曾完成 **214 树 / 26 维** C++ 排序器候选，并做过跨运行时数值校验。这里不重新训练。需要将**真正的训练模型实现**合入 C++ 推理核心后，在该核心的实际加载/绑定处实现：
- `int eg_active_trained_checkpoint_sha256_v2(char *out65, int capacity)`
- 只有当模型已实际加载、正在为 `eg_analyze_compute_policy_v2` 的候选打分时，返回其 64 位小写十六进制 SHA-256；否则返回 0。
- 目前此函数明确返回 **0**，因为公开分支尚未包含该模型产物。不能用 manifest 常量或构造的 token 冒充加载成功。
- 编译/安装相应检查点及真实训练推理，不应直接把个人 `.vltrain`、SQLite 或未许可训练数据提交公开仓库。

训练 Agent 将一个不含私人数据的 JSON 清单放入 iOS 应用 resources（路径示例：`Apps/iOS/Gomoku/Resources/ECLIPSE_ACTIVE_MODEL.json`，但要确认 xcodegen 实际 bundling）：

```json
{
  "schema": "eclipse.production-model-binding.v1",
  "model_id": "eclipse-1.0-astra",
  "training_revision": "R29",
  "checkpoint_sha256": "<actual 64-character SHA-256>",
  "compute_policy_sha256": "<actual policy SHA-256>",
  "compute_policy": {
    "mode": "adaptive",
    "max_wall_time_ms": null,
    "max_nodes": null,
    "max_depth": 15,
    "root_width": 60,
    "reply_width": 40,
    "continuation_width": 30,
    "forced_line_depth": 10,
    "candidate_radius": 5
  }
}
```

**上述内容是协议示例，版本号、R29 和搜索几何均为占位**；必须由训练 Agent 确认真实版本及参数，不得直接复制作为生产模型。不能以增加算力冒称升级训练世代。

## 公开仓库与授权边界
- 上述身份文件字段严格白名单，不允许插入真实用户棋谱、私人目录、完整训练历史。
- 历史五子棋档案仍沿用 `EclipseModelSelection` 可恢复的稳定值。
- 本 PR 只是正式执行架构 wiring；实际 214-tree 新检查点未在本仓库被验证加载，**不能宣布该新模型当前已经在 iOS 运行**。
- 上线前必须跑精确 head iOS XCTest + Release、C++ Core/C ABI、真机取消/过热/内存测试和模型加载→真实落子证明。
- Owner 负责正式发布裁决；本 PR 不擅自修改 main、签名、发布 IPA。
