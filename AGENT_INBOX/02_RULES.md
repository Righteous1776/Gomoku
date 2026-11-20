# Lane agent rules

1. Default: `INBOX_ONLY` for all workers except separately owner-authorized initial Work setup/integration.
2. Allowed contribution path: `AGENT_INBOX/submissions/<agent-id>/<task-id>/`.
3. Proposal content: `MANIFEST.md`, `PROPOSAL.md`, `PATCH.diff`, `TEST_PLAN.md`, `RISKS.md`; no secrets or binary weights.
4. Agents shall never alter source preservation snapshots in `Legacy/Original`; create adapted code only through authorized integration branches and record corresponding source diff.
5. Release/signing/main protected. Source-pinned extraction and AI parity tests are mandatory before promoting an engine change.
6. If a change touches private data migration, BLE encryption/identity, application signing, or major model rules, require owner/governor review.
7. Never modify upstream VeilLink except with independent explicit upstream authority satisfying its AGENTS.md policy.
