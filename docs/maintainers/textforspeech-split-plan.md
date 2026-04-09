# TextForSpeech Split, Source Lanes, and SpeakSwiftly Integration Plan

## Status

As of `2026-04-05`, the core split described here is functionally complete:

- `TextForSpeech` is the source of truth for text normalization models, runtime state, persistence, and normalization execution.
- `SpeakSwiftly` depends on `TextForSpeech` by local package path during development.
- `SpeakSwiftly.Runtime` exposes public text-profile inspection, editing, persistence, and request-time selection APIs.
- The current always-on base normalization behavior is preserved as an internal built-in profile layer inside `TextForSpeech`.

The remaining work from this plan has shifted from extraction to refinement:

- higher-level editing ergonomics
- YAML-backed configuration and hot reload
- additional format-specific normalization growth
- public API cleanup around text lanes versus source lanes
- structured source normalization, starting with Swift

## Goal

Finish the `TextForSpeech` extraction as a real package split instead of leaving it as a half-moved internal subsystem.

At the end of this work:

- `TextForSpeech` is the source of truth for text normalization models, runtime state, persistence, and normalization execution.
- `SpeakSwiftly` depends on `TextForSpeech` as an external package.
- `SpeakSwiftly` consumers can manage normalization profiles through public `SpeakSwiftly` APIs.
- speech requests can select a normalization profile and text format at request time.
- whole source files and mixed documents can use different normalization entrypoints.

## New API direction

The next durable building-block change was to stop forcing mixed text and whole source files through one ambiguous `normalize` entrypoint.

There are two real caller modes:

- mixed text such as Markdown, README-like prose, logs, or CLI output that may include embedded identifiers or code snippets
- whole source files where the caller already knows the language and wants a source-aware lane

The simpler path considered first was adding only `nestedFormat:` to the existing API. That helps mixed documents, but it still leaves whole-file source normalization trapped in the generic text lane.

That was not enough for the Xcode Source Extension case, so the package moved to an explicit split:

- `TextForSpeech.Normalize.text(...)`
- `TextForSpeech.Normalize.source(... as: ...)`

## Target public API

The intended public surface now centers on:

- `TextForSpeech.Normalize.text(_:, context:, profile:, format:, nestedFormat:)`
- `TextForSpeech.Normalize.source(_:, as:, context:, profile:)`
- `TextForSpeech.Normalize.detectTextFormat(in:)`
- `TextForSpeech.Forensics.features(originalText:normalizedText:)`
- `TextForSpeech.Forensics.sections(originalText:)`
- `TextForSpeech.Forensics.sectionWindows(originalText:totalDurationMS:totalChunkCount:)`

The old compatibility surfaces are gone. The split text/source API is now the only public direction.

## Format model direction

The public format model should be split into:

- `TextFormat`
  - `plain`
  - `markdown`
  - `html`
  - `log`
  - `cli`
  - `list`
- `SourceFormat`
  - `generic`
  - `swift`
  - `python`
  - `rust`

The old umbrella `Format` enum has been removed so the public model stays aligned with the split text/source lanes.

## Lane responsibilities

### Text lane

`normalizeText(...)` should own:

- caller-specified or detected outer text format
- mixed-content normalization for prose plus embedded identifiers
- optional nested source hinting for inline code, fenced code, and other code-like fragments

The text lane should continue using heuristic detection only for text containers.

### Source lane

`normalizeSource(... as: ...)` should own:

- explicit language selection by the caller
- whole-file or whole-buffer normalization
- future structured parsing for languages that earn it

The source lane should not rely on mixed-text heuristics.

## Nested source handling

Mixed documents should accept a nested source hint when the caller knows the language of embedded code.

That means:

- outer `format:` answers “what kind of document is this?”
- inner `nestedFormat:` answers “what kind of code tends to appear inside this document?”

Examples:

- `README.md` with Swift code fences
  - `format: .markdown`
  - `nestedFormat: .swift`
- HTML with embedded JavaScript would eventually use:
  - `format: .html`
  - `nestedFormat: <future source format>`

## Structured source roadmap

The source lane should support staged growth instead of pretending every language is equally understood today.

### Stage 1

- separate `normalizeSource(...)` API exists
- generic source fallback exists
- text lane can route embedded snippets through the source lane when the caller provides `nestedFormat`

### Stage 2

- add `SwiftSourceNormalizer`
- back it with `swiftlang/swift-syntax`
- normalize declarations, symbols, labels, and other syntax-aware structures more accurately than the generic token path

### Stage 3

- add additional language-specific normalizers such as Python when they earn their own parsing lane

## Compatibility strategy

The migration path should stay explicit and temporary:

1. add `TextFormat` and `SourceFormat`
2. add `normalizeText(...)`, `normalizeSource(...)`, and `detectTextFormat(in:)`
3. migrate package docs and tests to the new APIs
4. remove the old compatibility surface once downstream callers are updated

## Non-negotiable behavior

The current built-in normalization rules in `SpeakSwiftly` must be preserved.

Those rules should become the always-on base normalization profile in `TextForSpeech`, not optional custom overrides that can accidentally be turned off.

The intended model is:

- base profile:
  the currently hardcoded normalization behavior that keeps the model reliable and speakable
- custom profile:
  user or app-defined additions and overrides
- effective profile:
  the merged result of `base profile + selected custom profile`

So when a request normalizes text, it should never run only a custom profile by itself. It should always run the base profile, then merge in the selected custom profile on top.

That preserves reliability while still making customization useful.

## Why this split is worth doing

This is a durable building-block change, not cleanup for its own sake.

It unlocks real near-term use cases:

- package consumers can actually manage text normalization through public APIs
- `SpeakSwiftly` consumers can customize speech output without forking the built-in normalizer
- `TextForSpeech` can become a genuinely reusable package for other apps and tools
- persistence, import/export, YAML, and hot reload can live in the text system instead of leaking into speech-worker code

The simpler path considered first was keeping `TextForSpeech` as a mostly-standalone model package while `SpeakSwiftly` continued owning the real normalization behavior. That path should be rejected now because it preserves the current failure mode: two packages exist, but only one actually matters in practice.

## Target architecture

### TextForSpeech

`TextForSpeech` should own:

- `TextForSpeech.Context`
- `TextForSpeech.Replacement`
- `TextForSpeech.Profile`
- `TextForSpeech.Runtime`
- the concrete text normalizer implementation
- base-profile definition and effective-profile merging
- profile persistence
- later: config adapters such as YAML and hot reload

### SpeakSwiftly

`SpeakSwiftly` should own:

- worker protocol decoding and encoding
- request lifecycle
- playback
- voice profile storage
- queueing
- logging and observability
- request-time integration with `TextForSpeech`

`SpeakSwiftly` should not remain the owner of the normalization system once this split is complete.

## Required behavior model

### Base profile

`TextForSpeech` should define an internal built-in profile that captures the current built-in normalization behavior.

This base profile is not the same thing as an empty default profile.

It should represent the current always-on rules that make speech output reliable, including categories such as:

- fenced code handling
- inline code handling
- markdown link handling
- URL normalization
- Gale alias handling
- file path normalization
- identifier cleanup
- code-heavy line normalization
- spiral-prone word handling
- whitespace cleanup

The implementation may still keep some of those as built-in passes under the hood, but the package-level model should treat them as the base profile behavior, not as an unrelated invisible layer.

### Custom profile merging

Custom profiles should be merged with the base profile when loaded or selected.

That means the effective profile for a request should be:

1. start with the base profile
2. overlay the selected custom profile
3. preserve phase ordering and priority semantics

The important outcome is:

- built-in reliability stays on
- custom rules can extend or override it
- consumers do not have to rebuild the base behavior themselves

### Runtime semantics

`TextForSpeech.Runtime` should own:

- the active custom profile
- stored custom profiles
- the base profile
- effective-profile snapshots for new jobs
- persistence

Each new job should still capture a stable snapshot at start time.

## Public API outcomes

### TextForSpeech public API

`TextForSpeech` should expose a public API that supports:

- constructing profiles
- constructing replacement rules
- storing named profiles
- updating or replacing named profiles
- removing named profiles
- reading the base profile
- reading the active custom profile
- reading the effective merged profile
- snapshotting the effective profile for a new normalization job
- persistence load and save operations

Convenience APIs should be added so consumers do not have to constantly rebuild arrays by hand for every small change.

That likely means adding public methods along the lines of:

- append replacement
- update replacement
- remove replacement
- replace profile

The exact names should stay Swifty and value-oriented, but the workflow should stop feeling low-level.

### SpeakSwiftly public API

`SpeakSwiftly.Runtime` should expose public normalization-facing APIs such as:

- reading the current normalization state
- using a normalization profile
- storing a normalization profile
- removing a normalization profile
- resetting to base-only behavior
- choosing a normalization profile for a speech request
- choosing a text format for a speech request

The important practical outcome is that a `SpeakSwiftly` consumer can manage normalization without reaching around the runtime and rebuilding internal assumptions themselves.

## Implementation plan

### Phase 1: Build the real TextForSpeech package

In `../TextForSpeech`:

1. Move the current `TextForSpeech` models from `SpeakSwiftly` into the real package.
2. Move the actual normalizer implementation from `SpeakSwiftly` into `TextForSpeech`.
3. Move or recreate the relevant normalization tests there.
4. Define the base profile behavior explicitly.
5. Implement effective-profile merging.

Exit criteria:

- `TextForSpeech` can normalize text on its own
- the current built-in behavior is preserved
- the package has passing tests for profile selection and merging

### Phase 2: Add runtime ownership and persistence

In `../TextForSpeech`:

1. Expand `TextForSpeech.Runtime` so it owns:
   - base profile
   - active custom profile
   - stored custom profiles
   - effective-profile snapshots
2. Add persistence for text profiles.
3. Keep persistence format simple first, likely JSON on disk.
4. Add tests for:
   - base-only behavior
   - merged custom behavior
   - persistence round-trip
   - active-profile fallback after removal

Exit criteria:

- profiles are not only in-memory
- the package can reload persisted profiles
- the effective merged profile is stable and test-covered

### Phase 3: Adopt TextForSpeech in SpeakSwiftly

In `SpeakSwiftly`:

1. Add `TextForSpeech` as a package dependency.
2. Remove duplicated local `TextForSpeech` model ownership.
3. Remove duplicated local normalization implementation or leave only thin compatibility shims during migration, then delete them in the same pass.
4. Wire `SpeakSwiftly.Runtime` to own a `TextForSpeech.Runtime`.
5. Use request-time snapshots from that runtime when normalizing speech requests.

Exit criteria:

- `SpeakSwiftly` depends on external `TextForSpeech`
- `SpeakSwiftly` no longer acts as the hidden source of truth for normalization

### Phase 4: Expose real consumer-facing normalization APIs

In `SpeakSwiftly`:

1. Add public APIs to manage normalization profiles.
2. Extend speech request APIs so callers can specify:
   - normalization profile ID
   - text format
   - context
3. Extend the worker protocol if needed so the CLI/process boundary can also select profile and kind.
4. Add integration tests for:
   - base profile only
   - base plus custom profile
   - stored profile selection
   - profile persistence across runtime restarts if that is meant to apply in `SpeakSwiftly`

Exit criteria:

- a package consumer can actually use the profile system through `SpeakSwiftly`
- the package no longer exposes a mostly-theoretical normalization model

## Migration notes

During migration, avoid leaving long-term duplicate sources of truth in place.

If compatibility shims are temporarily needed, they should be explicitly temporary and removed before calling the split complete.

The final architecture should have:

- one source of truth for text normalization logic
- one source of truth for text profile runtime state
- one speech runtime that consumes that subsystem cleanly

## Deferred follow-up

These are good follow-up items, but they should not block the first complete split:

- YAML-backed configuration
- hot reload
- SwiftUI settings integration
- richer slice types as first-class public API
- more specialized match kinds such as path-segment or regex rules

The important thing is to finish the useful core first:

- base profile
- merged custom profiles
- persistence
- public `SpeakSwiftly` integration
