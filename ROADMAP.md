# ROADMAP

## Table of Contents

- [Vision](#vision)
- [Product Principles](#product-principles)
- [Milestone Progress](#milestone-progress)
- [Milestone 1: Core Normalization Package](#milestone-1-core-normalization-package)
- [Milestone 2: Runtime Profiles and Persistence](#milestone-2-runtime-profiles-and-persistence)
- [Milestone 3: Text and Source Lane API Split](#milestone-3-text-and-source-lane-api-split)
- [Milestone 4: Runtime Lookup and Profile Ergonomics](#milestone-4-runtime-lookup-and-profile-ergonomics)
- [Milestone 5: Structured Source Normalization](#milestone-5-structured-source-normalization)
- [Milestone 6: Forensic Surface Cleanup](#milestone-6-forensic-surface-cleanup)
- [Milestone 7: Release and Maintainability Polish](#milestone-7-release-and-maintainability-polish)
- [Milestone 8: Summary-Aware Normalization Requests](#milestone-8-summary-aware-normalization-requests)
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

- Milestone 1: Core Normalization Package - Completed
- Milestone 2: Runtime Profiles and Persistence - Completed
- Milestone 3: Text and Source Lane API Split - Completed
- Milestone 4: Runtime Lookup and Profile Ergonomics - Completed
- Milestone 5: Structured Source Normalization - Planned
- Milestone 6: Forensic Surface Cleanup - Completed
- Milestone 7: Release and Maintainability Polish - In Progress
- Milestone 8: Summary-Aware Normalization Requests - In Progress
- Milestone 9: Public API Model Cleanup - Planned
- Milestone 10: Style-Based Normalization Behavior and Codex Hook Review - In Progress

## Milestone 1: Core Normalization Package

### Status

Completed

### Scope

- [x] Ship the `TextForSpeech` library product for iOS 17 and macOS 14 through Swift Package Manager.
- [x] Normalize paths, identifiers, markdown, URLs, repeated separators, and repeated-letter runs through one package API.

### Tickets

- [x] Keep the main library namespace centered on `TextForSpeech`.
- [x] Preserve normalization through focused capability entrypoints instead of a broad flat API.
- [x] Cover mixed-input normalization behavior with Swift Testing.

### Exit Criteria

- [x] A caller can import the package and normalize code-heavy text without pulling in app-specific runtime code.
- [x] The baseline package build and test commands pass from the repository root.

## Milestone 2: Runtime Profiles and Persistence

### Status

Completed

### Scope

- [x] Support an observable runtime owner for active custom profiles and stored named profiles.
- [x] Support JSON-backed save, load, and restore flows for persisted profile state.
- [x] Keep default debug persistence separate from the production package store.

### Tickets

- [x] Keep `TextForSpeech.Runtime` as the owner of the active custom profile and stored profile state.
- [x] Support profile creation, storage, replacement updates, and removal through the runtime API.
- [x] Keep persistence errors descriptive and tied to concrete file operations.
- [x] Add focused tests that assert persistence and runtime error descriptions stay concrete and operator-readable.
- [x] Keep default debug persistence separate from the production package store for bundled hosts and fallback package runs.
- [x] Cover real file-backed persistence failures for invalid JSON, directory-backed reads, blocked parent directories, and directory-backed writes.

### Exit Criteria

- [x] A caller can create or edit stored profiles, read the active and effective profile views, and persist state to disk.
- [x] Runtime behavior is covered by the current Swift Testing suite.
- [x] Debug builds do not write into the production package store when callers use default persistence.

## Milestone 3: Text and Source Lane API Split

### Status

Completed

### Scope

- [x] Split mixed-text normalization from whole-source normalization at the public API level.
- [x] Finish the split in one pass instead of leaving compatibility shims behind.
- [x] Remove mixed-text nested source hints and keep embedded code generic unless the whole input uses the source lane.

### Tickets

- [x] Add `TextForSpeech.Normalize.text(...)`, `source(...)`, and `detectTextFormat(in:)`.
- [x] Split the public format model into `TextFormat` and `SourceFormat`.
- [x] Remove the old `normalize(... as:)` and `detectFormat(in:)` compatibility surface.
- [x] Remove `InputContext.textFormat`, `InputContext.nestedSourceFormat`, `InputContext`, and public `withContext` arguments.
- [x] Update package docs and tests to reflect the new API shape.
- [x] Cover `runtime.normalize.source(...)` active-profile and named-profile flows so the runtime source lane stays aligned with the public source API.

### Exit Criteria

- [x] Callers can choose a text lane or a source lane explicitly.
- [x] Mixed markdown-like inputs normalize embedded snippets without a request-wide source hint.
- [x] The package validates cleanly without compatibility shims or duplicate codepaths.

## Milestone 4: Runtime Lookup and Profile Ergonomics

### Status

Completed

### Scope

- [x] Tighten the profile lookup story so active, stored, and effective views are easy to reason about at the call site.
- [x] Keep the runtime grouped by capability without making callers bounce between near-duplicate lookup methods.
- [x] Preserve the current always-on base-profile merge behavior while clarifying raw custom-layer access.

### Tickets

- [x] Make `profiles` and `persistence` the public grouped entry points for external callers.
- [x] Keep the active custom layer explicit through `activeID`, `active()`, and `activate(id:)`.
- [x] Add focused docs and tests around the raw custom-layer view versus the built-in merged effective view.

### Exit Criteria

- [x] The runtime profile lookup story reads naturally at the call site without redundant concepts.
- [x] Docs and tests explain the distinction between raw custom profiles and effective merged profiles clearly.
- [x] `SpeakSwiftly` integration can choose a profile view without adapter glue or naming confusion.

## Milestone 5: Structured Source Normalization

### Status

Planned

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

## Milestone 6: Forensic Surface Cleanup

### Status

Completed

### Scope

- [x] Review the leftover forensic-facing APIs and helpers inherited from the earlier split work.
- [x] Decide which pieces belong to normalization parsing versus a separate analysis surface.
- [x] Tighten file placement and naming so production ownership is clearer.

### Tickets

- [x] Remove the old public `TextForSpeech.Forensics` namespace once SpeakSwiftly no longer depends on it.
- [x] Delete leftover helper code that only existed to support that surface when no internal production caller still uses it.
- [x] Refresh roadmap and maintainer-facing docs so they no longer describe a separate forensic area or public forensic capability.
- [x] Audit low-coverage parsing helpers and either cover the production callers or remove helpers that no longer materially support normalization.

### Exit Criteria

- [x] The package no longer ships a separate forensic API surface.
- [x] Shared parsing utilities live in normalization only when they materially support production normalization behavior.
- [x] File and type naming make it obvious that the remaining code is production normalization logic or runtime support rather than forensic analysis support.

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
- [ ] Add release notes for the parser-backed normalization and `InputContext` removal changes.

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
- Roadmap normalized to the canonical checklist schema with explicit remaining work for semantic-run migration, `NSDataDetector`, style review, Codex hook review, and structured source normalization.
