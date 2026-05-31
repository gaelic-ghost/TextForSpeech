# ROADMAP

## Table of Contents

- [Vision](#vision)
- [Product Principles](#product-principles)
- [Milestone Progress](#milestone-progress)
- [Milestone 5: Structured Source Normalization](#milestone-5-structured-source-normalization)
- [Milestone 7: Release and Maintainability Polish](#milestone-7-release-and-maintainability-polish)
- [Milestone 8: Summary-Aware Normalization Requests](#milestone-8-summary-aware-normalization-requests)
- [Milestone 8.1: Security Follow-Up for Summary Providers](#milestone-81-security-follow-up-for-summary-providers)
- [Milestone 9: Public API Model Cleanup](#milestone-9-public-api-model-cleanup)
- [Milestone 10: Style-Based Normalization Behavior and Codex Hook Review](#milestone-10-style-based-normalization-behavior-and-codex-hook-review)
- [Backlog Candidates](#backlog-candidates)
- [History](#history)

## Vision

- [ ] Keep `TextForSpeech` as the shared Swift source of truth for speech-safe normalization of code-heavy text, profile-driven pronunciation overrides, and reusable runtime profile state.

## Product Principles

- [ ] Keep normalization deterministic and reusable across callers instead of duplicating speech-cleanup rules in app code.
- [x] Keep the built-in normalization layer explicit as `Profile.base` and consistently merged so callers get one reliable normalization path.
- [x] Keep production normalization ownership explicit and avoid carrying a separate forensic API surface without a concrete package-level use case.
- [ ] Keep the public Swift surface grouped by capability, with namespace-first entrypoints and runtime handles that stay easy to discover in SourceKit.
- [ ] Prefer detection and documented style behavior over broad caller-provided behavior context objects.

## Milestone Progress

- Milestone 5: Structured Source Normalization - Planned
- Milestone 7: Release and Maintainability Polish - In Progress
- Milestone 8: Summary-Aware Normalization Requests - In Progress
- Milestone 8.1: Security Follow-Up for Summary Providers - Complete with Follow-Up Deferred
- Milestone 9: Public API Model Cleanup - Planned
- Milestone 10: Style-Based Normalization Behavior and Codex Hook Review - In Progress

## Milestone 5: Structured Source Normalization

### Status

In Progress

### Scope

- [ ] Add real Swift-aware source normalization for whole-source requests only.
- [ ] Keep the explicit source lane extensible for future Python and other language-specific parsers.
- [ ] Preserve a generic source fallback when no structured parser exists yet.

### Tickets

- [ ] Add the `swiftlang/swift-syntax` package at a toolchain-compatible release and wire a Swift-specific normalizer.
- [ ] Normalize Swift declarations, symbols, labels, and member access with syntax-aware traversal instead of token heuristics alone.
- [ ] Add coverage that proves the Swift source lane is materially more accurate than the generic source fallback on representative Swift code.
- [ ] Decide whether `SourceFormat.python` and `SourceFormat.rust` should remain as source-scoped replacement categories until real parser-backed lanes exist.

### Exit Criteria

- [ ] `TextForSpeech.Normalize.source(... as: .swift ...)` uses a structured Swift implementation rather than the generic source fallback.
- [ ] The package documents the current structured-source coverage honestly.
- [ ] Future language-specific source lanes can be added without reshaping the public API again.

## Milestone 7: Release and Maintainability Polish

### Status

In Progress

### Scope

- [ ] Keep source files role-focused so oversized catch-all files do not silently grow back.
- [ ] Keep public docs aligned with the real package architecture instead of preserving stale migration notes.
- [ ] Prepare the next minor release with updated roadmap and release notes.

### Tickets

- [x] Split the runtime implementation into grouped profile, persistence, and storage files.
- [x] Split normalization helpers by markdown passes, token passes, replacement engine, and format detection.
- [x] Refresh README and maintainer docs to reflect the current runtime and normalization model.
- [x] Prepare the next minor release notes and tag plan.
- [x] Add a small coverage-audit checklist for format detection, parsing helpers, runtime wrappers, and operator-facing error strings.
- [ ] Audit current source-file responsibilities after the parser-backed and context-cleanup work.
- [x] Add release notes for parser-backed normalization, slim `RequestContext`, request prefaces, and `InputContext` removal changes.

### Exit Criteria

- [ ] The package source layout is easy to scan without oversized catch-all files.
- [ ] Maintainer docs describe the current package architecture instead of the old migration state.
- [ ] The next minor release can be tagged and published from a clean, verified commit.

## Milestone 8: Summary-Aware Normalization Requests

### Status

In Progress

### Scope

- [x] Add an opt-in async normalization path that can summarize text before speech-safe normalization.
- [x] Keep deterministic normalization provider-free when callers leave `summarize` at its default `false` value.
- [x] Persist the selected summarization provider as runtime state instead of baking one provider into request handling.
- [ ] Harden provider-specific behavior with live integration checks and caller-facing guidance.

### Tickets

- [x] Add `TextForSpeech.SummarizationProvider` with `.codexExec`, `.openAIResponses`, `.foundationModels`, and `.test` backend options.
- [x] Add `runtime.summarizationProvider.get()`, `list()`, and `set(_:)`.
- [x] Add async `summarize:` normalization arguments for text and source requests.
- [x] Add a deterministic summary-execution test provider so `summarize: true` branches can be covered without live Codex, OpenAI, or Foundation Models calls.
- [ ] Add provider-specific integration tests or examples that can be run when credentials and platform support are available.
- [ ] Decide whether summary model selection needs a first-class package setting beyond provider selection.

### Exit Criteria

- [x] Callers can choose deterministic normalization or async summary-aware normalization explicitly at the call site.
- [x] Provider failures return descriptive errors that name the selected provider and the missing credential, platform support, or response failure.
- [x] README, maintainer docs, tests, and release notes describe the provider setting and request flag consistently.
- [ ] Provider-specific live checks or documented examples exist for supported non-test providers.

## Milestone 8.1: Security Follow-Up for Summary Providers

### Status

Complete with Follow-Up Deferred

### Scope

- [x] Harden summary-provider execution so opt-in providers fail boundedly instead of hanging, over-collecting output, or leaving child work behind.
- [x] Document and test the trust boundary where caller text leaves deterministic normalization and enters a summarizer.
- [x] Keep provider behavior explicit by preferring prompt boundaries, input/output limits, and provider-specific safety checks over broad text-rewriting or sanitization layers that would make normalization output less predictable.

### Tickets

- [x] Fix the `.codexExec` pipe-drain deadlock risk by reading stdout and stderr while the child process runs, adding a timeout, terminating on cancellation, and capping collected output.
- [x] Add a regression test with a fake `codex` executable that writes more than the pipe buffer and proves `.codexExec` fails boundedly instead of hanging.
- [x] Review summary prompt construction for untrusted caller text and add explicit untrusted-content boundaries, provider input size limits, provider output size limits, and non-sanitization documentation.
- [x] Decide whether Foundation Models should provide an optional prompt-risk preflight for live providers when available, while treating that check as defense in depth rather than a prompt-injection guarantee.
- [x] Keep `.foundationModels` on the Foundation Models framework instead of Writing Tools, because Writing Tools are a UIKit/AppKit text-view integration surface rather than a headless package summarization backend.
- [x] Check `SystemLanguageModel` availability before running the Foundation Models summary request and return provider-specific unavailable reasons.
- [x] Add docs that explain summary providers may transmit or process raw caller text, and that downstream callers own redaction before enabling live providers.
- [x] Add a maintainer options note for bounded execution, prompt boundaries, size policy, and optional Foundation Models preflight.
- [x] Preserve the May 2026 Codex Security scan report under `docs/security/reports/`.

### Exit Criteria

- [x] `.codexExec` summary calls cannot deadlock on child stdout or stderr backpressure.
- [x] Provider-specific text-boundary behavior is documented clearly enough for downstream services to make safe redaction and provider-selection decisions.
- [x] Security follow-up tests pass as part of `swift test`.

### Deferred Follow-Up

- [ ] Revisit Foundation Models prompt-risk preflight only if a downstream caller needs stricter local gating for live summary providers.

## Milestone 9: Public API Model Cleanup

### Status

Planned

### Scope

- [ ] Decide whether persisted JSON state is a public import/export contract or an internal runtime archive.
- [ ] Add a simpler public authoring path for common custom replacement rules.
- [ ] Keep the advanced replacement rule model available for built-ins and power users without making ordinary callers learn every internal rule field.

### Tickets

- [ ] Rework `TextForSpeech.PersistedState` into either a documented advanced archive contract or a hidden storage DTO behind narrower persistence APIs.
- [ ] Add convenience replacement authoring APIs for common phrase and whole-token pronunciation overrides.
- [ ] Update README, maintainer docs, tests, and release notes so persistence-state and replacement-authoring responsibilities are explicit.

### Exit Criteria

- [ ] Ordinary callers can save, load, back up, or restore runtime state without depending on accidental storage details.
- [ ] Ordinary callers can add common custom pronunciation rules without constructing the full low-level `Replacement` rule shape by hand.
- [ ] Advanced callers still have access to the full rule model when they need format scoping, phases, token transforms, or priorities.

## Milestone 10: Style-Based Normalization Behavior and Codex Hook Review

### Status

In Progress

### Scope

- [ ] Review URL, markdown-link, and path behavior through the existing built-in style model instead of adding a separate normalization policy type.
- [x] Remove caller-provided text-format and nested-source hints from mixed-text normalization.
- [x] Leave Codex-specific hook payload cleanup downstream for now instead of adding package-owned hook parsing.
- [ ] Move repeated token classification onto the internal semantic-run surface only after the desired behavior is documented in this roadmap and tests.

### Tickets

- [x] Design the style/context direction for URL, markdown-link, path, hook, and format-detection cleanup without adding a new normalization policy type.
- [x] Move `cwd` and `repoRoot` from `InputContext` into `RequestContext` so path shortening and request metadata share one context value.
- [x] Add a general request-context speech preface for `source` and `topic` without using path context or Codex-specific parsing.
- [x] Remove the previous `InputContext.textFormat` hint entirely and keep outer text-format routing detection-owned.
- [x] Remove `InputContext.nestedSourceFormat`; text normalization now uses generic embedded-code fallback instead of request-wide source hints.
- [x] Remove `InputContext` after moving durable request-local facts onto `RequestContext`.
- [x] Add `swift-markdown` and SwiftSoup dependencies, parser-backed structure helpers, and smoke tests for markdown and HTML detection.
- [x] Replace remaining markdown normalization helpers with `swift-markdown` traversal where structured extraction is needed; HTML has no custom normalization helper beyond SwiftSoup-backed structure detection.
- [x] Add an internal `AttributedString` semantic-run surface that annotates platform tokens and developer token kinds before normalization passes consume them.
- [x] Move URL normalization onto semantic runs backed by `NSDataDetector` link detection.
- [x] Add a semantic-run replacement helper and move file path and file-reference routing onto it.
- [x] Move function-call, issue-reference, and CLI-flag routing onto semantic runs.
- [ ] Review the existing semantic-run surface before changing normalization behavior so the next pass has a concrete file and call-site plan.
- [ ] Add a token-first detection pass using `NSDataDetector` for platform-supported semantic tokens such as links, addresses, dates, and phone numbers.
- [ ] Decide which `NSDataDetector` result types the package should actually speak by default versus merely mark for future use.
- [ ] Review developer-specific token detectors for paths, file-line references, identifiers, CLI flags, issue references, measured values, and scalar shorthands so they run independently from surrounding document format.
- [x] Move identifier normalization passes onto the `AttributedString` semantic-run surface so token detection happens once.
- [ ] Add focused tests before moving each existing token family onto semantic runs, starting with URLs and paths.
- [ ] Review `.compact`, `.balanced`, and `.explicit` against URL, markdown-link, and path behavior.
- [ ] Adjust built-in style presets, replacement transforms, and tests according to the style review.
- [x] Decide Codex-specific hook cleanup is downstream-owned for now; hook scripts can pre-clean payloads before text enters this package.
- [ ] Revisit package-owned hook cleanup only if real downstream payloads prove hook-script cleanup is the wrong ownership boundary.

### Exit Criteria

- [ ] Built-in styles have documented URL, markdown-link, and path behavior.
- [x] Text-format routing and embedded-code fallback are documented, tested, and no longer depend on broad context fields.
- [x] Codex hook ownership is settled for now as downstream hook-script cleanup, with no package-owned parsing behavior.
- [ ] Semantic-run migration has per-token-family tests and does not change public API shape.

## Backlog Candidates

- [ ] Add language-specific source lanes beyond Swift only after the Swift lane proves the shape.
- [ ] Reopen package-owned Codex hook cleanup only if real examples prove downstream hook-script cleanup is the wrong ownership boundary.
- [ ] Add public nested source-format inspection only if a concrete caller needs that signal separately from normalization.

## History

- Parser-backed normalization work added `swift-markdown`, SwiftSoup, and internal semantic token runs.
- Context cleanup moved path context onto `RequestContext` and removed `InputContext`, caller-provided text-format hints, and mixed-text nested-source hints.
- Added a security follow-up milestone for summary-provider pipe handling and untrusted-text boundary documentation after the May 2026 Codex Security scan.
- Completed early milestones are condensed here: the package now ships the core normalization library, runtime profile persistence, explicit text/source lanes, runtime profile ergonomics, and the forensic-surface cleanup.
- Roadmap normalized to the canonical checklist schema with explicit remaining work for semantic-run migration, `NSDataDetector`, style review, Codex hook ownership, and structured source normalization.
