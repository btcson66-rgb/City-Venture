# Repository publication and Actions audit — 2026-10-08

Repository: btcson66-rgb/City-Venture. The owner explicitly authorized publication after safety checks. Visibility was changed using GitHub CLI, then GitHub API read back `private=false`, `visibility=public`; anonymous API and web requests both returned HTTP 200. No repository recreation, branch/tag deletion, history rewrite, issue/PR/release removal or paid service enablement occurred.

## Safety evidence

- Fresh GitHub heads/tags snapshot: 100 branches, 0 tags. Every remote SHA matched the audited refs. Publication preserved the entire snapshot exactly. Local mirror also includes all advertised PR heads and 529 reachable commits.
- Gitleaks 8.30.1: working tree ~122.63 MB, all historical text patches ~114.19 MB, no credentials found. The patch scan includes 427 commits with relevant changes (merge/no-text-change commits are also represented in the 529-commit reachable graph).
- Supplementary full-content scan: 12,849 unique historical non-media objects, 0 missing; 11 gzip-encoded game saves decompressed before scanning; ~547.12 MB, no credentials found. Private-network/credential-URL and Supabase/Cloudflare assignment checks found 0 candidates. `.env`, key/password/config paths were included; no private deployment key material was found.
- Actions: all 330 completed historical run log archives and all 315 unexpired artifacts downloaded and scanned, together with Issues and issue/review comments. Final scan ~852.02 MB; no credentials found. Download redirects dropped GitHub Authorization on cross-host redirects. No archive contents were published as part of this audit.
- Repository-level Actions Secrets: 0; environments: 0; self-hosted runners: 0. No values were exported from GitHub Secrets. No committed valid credentials were discovered, so no credential revocation/rotation was necessary.
- Game data/QA saves represent fictional companies, people and native game transactions. Public project/owner handles, intentional person/brand names, localhost smoke-test URLs and ordinary commit metadata are retained. No customer/contact dataset or internal Supabase/Cloudflare endpoint was found.
- Music and foley: original deterministic synthesis, documented in AUDIO_CREDITS.md and tools/media. Art: original procedural/generated assets with manifests/prompts in ART_ASSET_MANIFEST.md and docs/art_sources. The owner confirmed all seven supplied concept boards were AI-generated; provenance is recorded beside the boards. Fonts: Inter, Pixelify Sans and Noto CJK subsets retain their shipped SIL OFL notices. No third-party nonredistribution restriction was found; no new project-wide license was assigned.
- Secret scanning is not a mathematical proof of absence. Binary image/audio/font files are assessed through path inventories, source provenance and bundled font licenses; they are not treated as plaintext configuration. Compressed text saves and Actions archives were inspected as content. Audit reports/raw downloads remain outside Git to avoid exposing private data if later findings arise.

## Actions cost changes

Snapshot: 330 runs (150 pull_request, 180 push). Same workflow/head SHA had 145 dual-event pairs. Before, feature-branch push and PR triggered duplicate test jobs and used different concurrency groups.

Quality and map workflows now use PR validation on every PR, plus push validation on the default `claude/exciting-bardeen-y71ixv` branch after merge; workflow_dispatch is available for intentional pre-PR reruns. Every existing test and quality gate is retained. Both workflows cancel superseded runs per PR/branch. No path-based skip can leave an expected PR check pending.

Godot 4.5.1 official Linux x86_64 ZIP is cached and checked against release SHA256 `02ec53d1cc7dbb9cc6355393c61b9ab43d1244751a124f10248a4802830788cd` on every use. Python tools are pinned and use pip cache. New report artifacts retain 14 days instead of the default 90. No existing artifacts/logs were deleted. Only standard ubuntu-24.04 GitHub-hosted runners are used; larger runners, billing limits and paid add-ons were not enabled or raised.

There is no CI deployment workflow on the default branch, no Pages site and no deployment environment. Original manual release scripts remain intact. Actions enabled/allowed-actions settings and default workflow read permissions are preserved.

## Rules and verification

Before publication: no rulesets; all 100 branches unprotected; default branch protection API returned 404 Branch not protected. After publication: the same empty rulesets and unprotected branch flags. No merge rule was weakened.

Actionlint 1.7.12 passed. Local i18n missing 0, wiki, beta, pose, map check, 7 map-validator and 15 performance-validator tests passed. Godot unit tests and GitHub quality CI were still running when this record was authored; their final outcomes are reported in PR #172 and the delivery report, not inferred here.

While private, GitHub refused all three CI jobs before any step started with the account payments/spending-limit annotation. Publication was performed only after independent safety checks passed, never to bypass a safety gate. The same standard-runner workflows were rerun after publication without changing billing settings.

PR: https://github.com/btcson66-rgb/City-Venture/pull/172
Quality rerun: https://github.com/btcson66-rgb/City-Venture/actions/runs/37731104560
Map rerun: https://github.com/btcson66-rgb/City-Venture/actions/runs/37731104231

F1–F8: N/A for this infrastructure-only change; no game mechanics, save migrations, Ledger rules or player UI were changed.
