# Gomoku Agent Governance (repository starter)

Authority: (1) repository owner, (2) designated Integration Governor, (3) scoped integration agents. No agent may unilaterally merge to `main`, publish a release, rotate signing identities, rewrite upstream source, or weaken ECLIPSE parity gates.

## Default mode
`INBOX_ONLY`: read-only inspection of product source, plus proposals written under `AGENT_INBOX/submissions/<agent-id>/<task-id>/` with `MANIFEST.md`, `PROPOSAL.md`, `PATCH.diff`, `TEST_PLAN.md`, `RISKS.md`. A separate owner-approved setup/integration grant is required to edit product code during the initial bootstrap. Do not treat this handoff file as implicit permission to modify the **upstream** VeilLink repo.

## Source fidelity
`Legacy/Original` is an unmodified, SHA256-audited staging layer. Never change staged upstream files in place. All adapted copies must live in distinct paths and must be traceable to upstream source paths, commit, and diffs. Preserve MIT copyright attribution and third-party licenses.

## Build and release
`main` integration only after CI + original game behavior + performance + model parity + data migration + device smoke tests. All signed IPA / app publication require verified owner release approval and secure external signing infrastructure. CI `unsigned-ipa-dev.yml` output is a testing artifact, NOT a customer-installable IPA.

## Confidentiality
Never commit personal matches, chats, training archives containing user data, hardware keys, certificate/signing artifacts, account credentials or unverified third-party weights. Keep all migration exports user-initiated and app sandbox-safe.

## Emergency stop
Stop and report on source rollback, destructive deletion, accidental overwrite, privacy leak, missing licensing, AI strength regression, unexpected dependency into unrelated messaging features, or signing/release mutation.
