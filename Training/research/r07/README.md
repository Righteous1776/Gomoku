# R07 公开训练源码归档（研究-only）

本目录包含三个实际研究源码入口以及 [`checkpoints/`](./checkpoints/README.md) 中 **7 个完整、SHA 校验一致的原始 LightGBM 模型权重**。这是按 Owner 后续明确要求发布的研究参数；**不包含**用户及朋友的原始棋谱、私人 SQLite、40 份历史局面私有标注或任何实际个人训练导出。权重由私人真人对局训练，发布权重本身仍有模型记忆风险。

| 文件 | 作用 | 运行前提 |
|---|---|---|
| `source/features34.py` | 固定 26D 统计特征后加 8 维确定性战术几何特征 | 原研究包 `ECLIPSE_Training_R04/base/data_pipeline.py`、NumPy、Numba |
| `source/train_r07.py` | R04 的 26D→34D 无损扩展、残差训练和五个检查点的九项门禁 | 原 R04/R05/R06 训练脚本、用户自行保管的私有数据、实际 R04 权重、LightGBM |
| `source/arena_ranker_r07.py` | 15×15 规则、双模型交换先后手的完整研究对局 | 上述特征与基础工具、两个原研究权重、NumPy、LightGBM |

## 恢复原始研究目录结构

脚本保留了原始的相对引用方式。恢复时将这里的三个文件分别复制到如下原始研究布局（不要直接让它们在 `Training/research/r07/source` 里执行）：

```text
<local-private-research-root>/
  ECLIPSE_Training_R04/
    eclipse_r04_research_lightgbm.txt     # private-derived; must match published SHA
    audit_r04.py
    train_r04.py
    base/data_pipeline.py
    base/train_r03.py
    base/train_eclipse_r02.py
    base/v9_casepack_hex.txt
    private/real40_corrected.hex          # not published
  ECLIPSE_Training_R05/train_r05.py
  ECLIPSE_Training_R06/
    train_r06.py
    features34.py                         # copy source/features34.py here
    external/winepy_samples.b64txt        # MIT source, not yet committed here
  ECLIPSE_Training_R07/
    train_r07.py                          # copy source/train_r07.py here
    arena_ranker_r07.py                   # copy source/arena_ranker_r07.py here
```

原始私人对局与测试材料未进入公开 GitHub；基座和 R07 研究权重已在本目录的 `checkpoints/` 公开提供。即使恢复脚本文件，**缺少用户自己的七份原始 .vltrain 与私有历史测试 fixture 时，也无法真实重训得到声明的检查点**。所有检查点仍需核对 `r07_public_metrics.json` 中登记的 SHA，绝不以相近权重冒称完全一致。

## 可信度

- 本文与公开聚合指标属于研究归档；R07 **未晋级**，不等于当前 iOS 应用正在使用的模型。
- R07-249 的 1,024 局是深度 0 静态排序器的真正落子对抗，不是 V9 原生搜索对抗，没有 Elo 认证。
- 真正学习“什么时候停止思考”的算法接口属于另一系列工程分支：#59 / #60，不能把该研究排序权重误当作自适应时间策略。
- 与本仓库核心训练测试互不污染：这些源码没有注册为正式生产编译目标。

完整聚合数据：[R07 public metrics](../r07_public_metrics.json)；总审计：[R01–R07 报告](../../../Docs/Research/ECLIPSE_TRAINING_R01_R07_PUBLIC_AUDIT.md)。
