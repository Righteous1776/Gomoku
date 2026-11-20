# Explicit match transfer candidate

The independent Gomoku app can only access another app's data when the user exports a supported file and selects it using the system Files picker. It never reads VeilLink's sandbox. The user-facing "导入棋谱 JSON" validates a single exported original VeilGomokuMatchArchive.Match JSON record, its UUID, shape, turn-order replay and final win/draw state, and inserts via the original append-only archive's atomic save. Existing match UUIDs are never overwritten. No arbitrary game count cap is introduced; 128KB is a per-single-match decode ceiling. Export latest match creates a temporary shareable JSON; the user controls its destination.

NOT IMPLEMENTED: legacy VeilLink full AdaptiveBoardLearningStore import/export, native selfplay bulk upload and model feedback; multi-game ZIP/streaming; direct app-to-app sandbox access; signed release.

Mac Xcode and XCTest required. Do not merge until user/Owner review and source/BLE dependencies.
