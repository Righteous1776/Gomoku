# ECLIPSE R04 / R07 · Original model checkpoints (public research artifacts)

This folder contains **seven full, byte-exact LightGBM Booster text files**, not checkpoints reconstructed from statistics. Model SHA-256 and Git blob SHA-1 are in [MODEL_MANIFEST.json](./MODEL_MANIFEST.json). Total **4,166,924 original bytes**.

- Original R04 ranker: **239 trees / 26D**.
- R04 shape-compatible base: **239 trees / 34D**, identical outputs for the prior first 26 features in the research replay probe.
- R07 snapshots: **244, 249, 259, 274, 289 trees / 34D**.
- **R07-249** is the best exploratory balance, not an approved release. It passed **8/9 gates** and failed 40 historical human-move agreement (21/40 vs R04 22/40). Those historical moves are weak labels, not mathematically proven best moves.
- R07 R04-vs-R07 1,024 games were a depth-zero static-ranker arena, **not V9 engine matches, not Elo**.
- **No private .vltrain, personal match transcript, private history board test fixture or private SQLite** is included in this folder. **But the model parameters were trained on private user game data**: publishing weights is public distribution of learned parameters and has residual memorization/privacy risk.

## Loading

```python
import lightgbm as lgb
model = lgb.Booster(model_file="eclipse_r07_34d_249_trees.txt")
assert model.num_trees() == 249 and model.num_feature() == 34
```

The original 34-dimensional deterministic feature extractor lives at [../source/features34.py](../source/features34.py) and depends on the 26D R04 base feature pipeline. Loading a 34D Booster alone **does not** replace an iOS Gomoku production model. Add the precise feature implementation, SHA verification, native/Swift conformance, tactical gates and paired engine evaluation before considering promotion.

### Public provenance and release boundary

- Source model archive SHA-256: `6b00ca26b53a61d70c0cc1d69a2c35cce74fe253b5f968087839a17b78f5f51f`.
- The Owner explicitly requested publication of the research model checkpoints to GitHub. The underlying personal match files remain excluded.
- The contents are public artifacts of research, **NOT a certified V9/Astra/Sol production model**, and must not be auto-selected by production or inserted into a signed IPA.
