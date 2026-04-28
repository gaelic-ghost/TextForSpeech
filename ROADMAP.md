# ROADMAP

## Vision

- [ ] Keep `TextForSpeech` as the shared source of truth for speech-safe normalization of code-heavy text and profile-driven pronunciation overrides.

## Product principles

- [ ] Keep normalization deterministic and reusable across callers instead of duplicating speech-cleanup rules in app code.
- [x] Keep the built-in normalization layer explicit as `Profile.base` and consistently merged so callers get one reliable normalization pipeline.
- [x] Keep production normalization ownership explicit and avoid carrying a separate forensic API surface without a concrete package-level use case.
- [ ] Keep the public Swift surface grouped by capability, with namespace-first entrypoints and runtime handles that stay easy to discover in SourceKit.

## Milestone Progress

- [x] M1 Core normalization package
- [x] M2 Runtime profiles and persistence
- [x] M3 Text and source lane API split
- [x] M4 Runtime lookup and profile ergonomics
- [ ] M5 Structured source normalization
- [x] M6 Forensic surface cleanup
- [ ] M7 Release and maintainability polish
- [ ] M8 Summary-aware normalization requests

## M1 Core normalization package

### Scope

- [x] Ship the `TextForSpeech` library product for iOS 17 and macOS 14 through Swift Package Manager.
- [x] Normalize paths, identifiers, markdown, URLs, repeated separators, and repeated-letter runs through one package API.

### Tickets

- [x] Keep the main library namespace centered on `TextForSpeech`.
- [x] Preserve normalization through focused capability entrypoints instead of a broad flat API.
- [x] Cover mixed-input normalization behavior with Swift Testing.

### Exit criteria

- [x] A caller can import the package and normalize code-heavy text without pulling in app-specific runtime code.
- [x] The baseline package build and test commands pass from the repository root.

## M2 Runtime profiles and persistence

### Scope

- [x] Support an observable runtime owner for active custom profiles and stored named profiles.
- [x] Support JSON-backed save, load, and restore flows for persisted profile state.

### Tickets

- [x] Keep `TextForSpeech.Runtime` as the owner of the active custom profile and stored profile state.
- [x] Support profile creation, storage, replacement updates, and removal through the runtime API.
- [x] Keep persistence errors descriptive and tied to concrete file operations.

### Exit criteria

- [x] A caller can create or edit stored profiles, read the active and effective profile views, and persist state to disk.
- [x] Runtime behavior is covered by the current Swift Testing suite.

## M3 Text and source lane API split

### Scope

- [x] Split mixed-text normalization from whole-source normalization at the public API level.
- [x] Finish the split in one pass instead of leaving compatibility shims behind.
- [x] Let mixed documents carry an explicit nested source hint for embedded code.

### Tickets

- [x] Add `TextForSpeech.Normalize.text(...)`, `source(...)`, and `detectTextFormat(in:)`.
- [x] Split the public format model into `TextFormat` and `SourceFormat`.
- [x] Remove the old `normalize(... as:)` and `detectFormat(in:)` compatibility surface.
- [x] Update package docs and tests to reflect the new API shape.

### Exit criteria

- [x] Callers can choose a text lane or a source lane explicitly.
- [x] Mixed markdown-like inputs can route embedded snippets through an explicit nested source format.
- [x] The package validates cleanly without compatibility shims or duplicate codepaths.

## M4 Runtime lookup and profile ergonomics

### Scope

- [x] Tighten the profile lookup story so active, stored, and effective views are easy to reason about at the call site.
- [x] Keep the runtime grouped by capability without making callers bounce between near-duplicate lookup methods.
- [x] Preserve the current always-on base-profile merge behavior while clarifying raw custom-layer access.

### Tickets

- [x] Make `profiles` and `persistence` the public grouped entry points for external callers.
- [x] Keep the active custom layer explicit through `activeID`, `active()`, and `activate(id:)`.
- [x] Add focused docs and tests around the raw custom-layer view versus the built-in merged effective view.

### Exit criteria

- [x] The runtime profile lookup story reads naturally at the call site without redundant concepts.
- [x] Docs and tests explain the distinction between raw custom profiles and effective merged profiles clearly.
- [x] `SpeakSwiftly` integration can choose a profile view without adapter glue or naming confusion.

## M5 Structured source normalization

### Scope

- [ ] Add a language-aware Swift source lane backed by SwiftSyntax.
- [ ] Keep the explicit source lane extensible for future Python and other language-specific parsers.
- [ ] Preserve a generic source fallback when no structured parser exists yet.

### Tickets

- [ ] Add the `swiftlang/swift-syntax` package at a toolchain-compatible release and wire a Swift-specific normalizer.
- [ ] Normalize Swift declarations, symbols, labels, and member access with syntax-aware traversal instead of token heuristics alone.
- [ ] Add coverage that proves the Swift source lane is materially more accurate than the generic source fallback on representative Swift code.

### Exit criteria

- [ ] `normalizeSource(... as: .swift ...)` uses a structured Swift implementation rather than the generic source fallback.
- [ ] The package documents the current structured-source coverage honestly.
- [ ] Future language-specific source lanes can be added without reshaping the public API again.

## M6 Forensic surface cleanup

### Scope

- [x] Review the leftover forensic-facing APIs and helpers inherited from the earlier split work.
- [x] Decide which pieces belong to normalization parsing versus a separate analysis surface.
- [x] Tighten file placement and naming so production ownership is clearer.

### Tickets

- [x] Remove the old public `TextForSpeech.Forensics` namespace once SpeakSwiftly no longer depends on it.
- [x] Delete leftover helper code that only existed to support that surface when no internal production caller still uses it.
- [x] Refresh roadmap and maintainer-facing docs so they no longer describe a separate forensic area or public forensic capability.

### Exit criteria

- [x] The package no longer ships a separate forensic API surface.
- [x] Shared parsing utilities live in normalization only when they materially support production normalization behavior.
- [x] File and type naming make it obvious that the remaining code is production normalization logic or runtime support rather than forensic analysis support.

## M7 Release and maintainability polish

### Scope

- [ ] Keep source files role-focused so oversized catch-all files do not silently grow back.
- [ ] Keep public docs aligned with the real package architecture instead of preserving stale migration notes.
- [ ] Prepare the next minor release with updated roadmap and release notes.

### Tickets

- [x] Split the runtime implementation into grouped profile, persistence, and storage files.
- [x] Split normalization helpers by markdown passes, token passes, replacement engine, and format detection.
- [x] Refresh README and maintainer docs to reflect the current runtime and normalization model.
- [x] Prepare the next minor release notes and tag plan.

### Exit criteria

- [ ] The package source layout is easy to scan without oversized catch-all files.
- [ ] Maintainer docs describe the current package architecture instead of the old migration state.
- [ ] The next minor release can be tagged and published from a clean, verified commit.

## M8 Summary-aware normalization requests

### Scope

- [x] Add an opt-in async normalization path that can summarize text before speech-safe normalization.
- [x] Keep the existing synchronous normalization API deterministic and provider-free.
- [x] Persist the selected summary provider as runtime state instead of baking one provider into request handling.
- [ ] Harden provider-specific behavior with live integration checks and caller-facing guidance.

### Tickets

- [x] Add `TextForSpeech.SummaryProvider` with distinct `.codexExec`, `.openAIResponses`, and `.foundationModels` cases.
- [x] Add `runtime.summaryProvider.get()`, `list()`, and `set(_:)`.
- [x] Add async `summarize:` normalization entrypoints for text and source requests.
- [ ] Add provider-specific integration tests or examples that can be run when credentials and platform support are available.
- [ ] Decide whether summary model selection needs a first-class package setting beyond provider selection.

### Exit criteria

- [ ] Callers can choose deterministic normalization or async summary-aware normalization explicitly at the call site.
- [ ] Provider failures return descriptive errors that name the selected provider and the missing credential, platform support, or response failure.
- [ ] README, maintainer docs, tests, and release notes describe the provider setting and request flag consistently.
