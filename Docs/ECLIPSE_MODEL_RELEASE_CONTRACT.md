# ECLIPSE model release contract — R14

## Real model selection, not cosmetic tiers
The user selects an immutable versioned **ECLIPSE model-policy artifact** which
determines a real search implementation, search depth/width and compute budget.
Changing policy, weights or runtime means allocating a new model identifier.

| Model ID | UI | Runtime | FULL per-move time budget |
|---|---|---|---|
| eclipse-1.0-luna | 1.0 Luna | Swift Classic heuristic search | 130ms |
| eclipse-1.0-terra | 1.0 Terra | Swift R10 trained unified search | 260ms |
| eclipse-1.0-sol | 1.0 Sol | Swift R10 trained unified search | 520ms |
| eclipse-1.1-sol | 1.1 Sol | Swift R10 trained unified search | 950ms |
| eclipse-1.0-astra | 1.0 Astra | Swift R10 trained unified search | 1,900ms |
| eclipse-1.1-astra | 1.1 Astra | Swift R10 trained unified search | 3,800ms |
| eclipse-1.2-astra | 1.2 Astra | Swift R10 trained unified search | 5,700ms |

All models retain original GomokuBot forced-win/block safety logic.
Luna deliberately selects the independent classic fallback search path.
Other models share the native Swift trained R10/R12/R13 search core but have
different search policies and limits. **They are not independently trained
neural weights / separate neural networks.** The UI must disclose this.
6× means maximum *search budget*, NOT Elo or actual playing-strength multiple.
User-selected Economy vs Full search mode stays an orthogonal setting.

## Gate to separately trained models (R15+)
- A real independently trained model must have its own immutable checkpoint
  or evaluator policy artifact and SHA-256, recorded dataset provenance,
  architecture/release metadata, immutable version and supported runtime.
- Run private owners' VeilLink training only in local private environment.
  Never push raw user histories or positions to public GitHub/Inbox.
- Preserve repeated owner-discovered tactics and provenance. Never inflate
  independent sample size by summing overlapping exports or D4 rotations.
- Test all search tiers on hardware with actual CPU, memory, wall time and
  thermal evidence. Full trained Swift ECLIPSE is the noninferiority baseline.
- Do not promote the experimental C++ engine, rename budgets as Elo, or claim
  independently trained model weights without actual data and CI proof.
- Final promotion requires Owner review and an explicit release decision.

## Persistence and attribution
- Stable UserDefaults key: gomoku.eclipse.selected-model-id.v1.
- Each new game archive contains its model ID in the previous difficulty
  string field, without changing the archive's JSON structure.
- Old archives with raw values relaxed/balanced/advanced/master/grandmaster/
  legendary/zenith continue to restore via deterministic migration and do not
  have their original bytes rewritten.
- Changing model mid-game requests confirmation and starts a new game; the
  prior game is retained according to existing interruption rules.
- Only the completed asynchronous worker can update lastExecutedModel; the
  selected model in the UI is not falsely presented as an executed move.

## Governance
Draft PR only, no main or VeilLink edits, no IPA or silent production engine
replacement, no publication of private training material. Candidate strength
parity remains a separate blocking gate.
