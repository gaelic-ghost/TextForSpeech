# ROADMAP

## Vision

- [ ] Keep `TextForSpeech` as the shared source of truth for speech-safe normalization of code-heavy text, profile-driven pronunciation overrides, and lightweight forensic inspection of segmented input.

## Product principles

- [ ] Keep normalization deterministic and reusable across callers instead of duplicating speech-cleanup rules in app code.
- [ ] Keep the built-in normalization layer and custom profile layer explicit so callers can reason about what is always on versus what they changed.
- [ ] Keep forensic APIs honest about what they measure and separate from the production normalization path unless shared primitives clearly belong in both places.

## Milestone Progress

- [x] M1 Core normalization package
- [x] M2 Runtime profiles and persistence
- [x] M3 Text and source lane API split
- [ ] M4 Structured source normalization
- [ ] M5 Forensic surface cleanup

## M1 Core normalization package

### Scope

- [x] Ship the `TextForSpeech` library product for macOS 15 through Swift Package Manager.
- [x] Normalize paths, identifiers, markdown, URLs, repeated separators, and repeated-letter runs through one package API.

### Tickets

- [x] Keep the main normalization entrypoint centered on `TextForSpeech.normalize(_:context:profile:as:)`.
- [x] Preserve format detection through `TextForSpeech.detectFormat(in:)`.
- [x] Cover mixed-input normalization behavior with Swift Testing.

### Exit criteria

- [x] A caller can import the package and normalize code-heavy text without pulling in app-specific runtime code.
- [x] The baseline package build and test commands pass from the repository root.

## M2 Runtime profiles and persistence

### Scope

- [x] Support an observable runtime owner for active custom profiles and stored named profiles.
- [x] Support JSON-backed save, load, and restore flows for persisted profile state.

### Tickets

- [x] Keep `TextForSpeechRuntime` as the owner of `baseProfile`, `customProfile`, and stored profile state.
- [x] Support profile creation, storage, replacement updates, and removal through the runtime API.
- [x] Keep persistence errors descriptive and tied to concrete file operations.

### Exit criteria

- [x] A caller can create or edit stored profiles, snapshot an effective profile, and persist state to disk.
- [x] Runtime behavior is covered by the current Swift Testing suite.

## M3 Text and source lane API split

### Scope

- [x] Split mixed-text normalization from whole-source normalization at the public API level.
- [x] Preserve legacy callers through compatibility forwarding while downstream packages migrate.
- [x] Let mixed documents carry an explicit nested source hint for embedded code.

### Tickets

- [x] Add `normalizeText(...)`, `normalizeSource(...)`, and `detectTextFormat(in:)`.
- [x] Split the public format model into `TextFormat` and `SourceFormat`.
- [x] Keep the old `normalize(... as:)` and `detectFormat(in:)` entrypoints as compatibility shims.
- [x] Update package docs and tests to reflect the new API shape.

### Exit criteria

- [x] Callers can choose a text lane or a source lane explicitly.
- [x] Mixed markdown-like inputs can route embedded snippets through an explicit nested source format.
- [x] The package still validates cleanly with backward-compatibility coverage in place.

## M4 Structured source normalization

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

## M5 Forensic surface cleanup

### Scope

- [ ] Review the current forensic-facing section APIs and helpers.
- [ ] Decide which pieces belong to normalization parsing versus forensic analysis.
- [ ] Tighten file placement and naming so production ownership is clearer.

### Tickets

- [ ] Audit `TextForSpeech.forensicFeatures`, `sections`, and `sectionWindows` against the underlying parsing helpers they rely on.
- [ ] Separate genuinely shared normalization primitives from forensic-only helpers.
- [ ] Rename or relocate forensic-facing files if the current layout still blurs ownership.

### Exit criteria

- [ ] The forensic API surface has clear ownership boundaries.
- [ ] Shared parsing utilities live where both normalization and forensics can use them without duplicate codepaths.
- [ ] File and type naming make it obvious which code is production normalization logic and which code is forensic analysis support.
