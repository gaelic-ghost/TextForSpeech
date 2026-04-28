# TextForSpeech Split Status and Source Layout

## Status

The original extraction and lane split are complete.

As of `2026-04-28`, the package now owns:

- normalization models
- the built-in base profile
- runtime-owned stored custom profiles and active-profile selection
- default-on profile persistence
- async mixed-text and whole-source normalization entrypoints
- summary-configuration selection for opt-in summary-aware normalization

The remaining work has shifted from package extraction to package refinement.

## What was completed

The main architectural pivots from the original split plan are now in place:

- `TextForSpeech` is the source of truth for normalization, profile state, and persistence.
- `TextForSpeech.Normalize.text(...)` and `TextForSpeech.Normalize.source(...)` are the public async lane split.
- `TextFormat` and `SourceFormat` replaced the old umbrella format model.
- `InputContext` carries input-local path and format hints separately from `RequestContext` request metadata.
- runtime persistence defaults to Application Support.
- the built-in normalization policy moved into composable built-in profile layers with a selectable style preset.

The simpler path considered first was leaving the old hard-coded built-ins in the normalizer while only extracting the models. That path was rejected because it would have preserved a split package where only one side really owned the behavior that mattered.

## Current source layout

The current source tree is organized by responsibility.

### `Sources/TextForSpeech/API`

Public namespace-first entrypoints:

- `NormalizationAPI.swift`

### `Sources/TextForSpeech/Models`

Shared value types and built-in profile definitions:

- `Profile.swift`
- `BuiltInProfiles.swift`
- `Replacement.swift`
- `InputContext.swift`
- `Format.swift`
- `SummaryProvider.swift`

### `Sources/TextForSpeech/Normalization`

The normalization engine is now split by role instead of collecting all helpers in one oversized file:

- `TextNormalizer.swift`
  Pipeline driver and public internal entrypoints.
- `MarkdownNormalizationPasses.swift`
  Fenced-code, inline-code, and markdown-link transforms.
- `TokenNormalizationPasses.swift`
  Built-in lexical pass wrappers that route through the default balanced built-in base.
- `FormatDetection.swift`
  Text and source-lane heuristics.
- `ReplacementRuleEngine.swift`
  Replacement application and transform resolution.
- `ReplacementRuleMatching.swift`
  Token-kind and line-kind match helpers.
- `ParsingUtilities.swift`
  Shared markdown and token parsing helpers.
- `SpeechConversion.swift`
  Low-level spoken-form helpers.
- `TextNormalizer+...`
  Smaller focused helpers for heuristics, path context, speech helpers, and detection.
- `SourceNormalizer.swift`
  Source-lane routing.
- `TextSummarizer.swift`
  Async summary execution used only when callers opt into summary-aware normalization.

### `Sources/TextForSpeech/Runtime`

Runtime code is now split by capability:

- `TextForSpeechRuntime.swift`
  Core runtime type and public grouped accessors.
- `TextForSpeechRuntime+Profiles.swift`
  Public profile operations.
- `TextForSpeechRuntime+Persistence.swift`
  Public persistence operations.
- `TextForSpeechRuntime+Summary.swift`
  Public summary-configuration selection operations.
- `TextForSpeechRuntime+Storage.swift`
  Default persistence path resolution and runtime state repair helpers.
- `PersistedState.swift`
  JSON-backed persisted-state shape.
- `Errors.swift`
  Runtime and persistence errors.

## Architectural boundaries

The package is easier to maintain when these boundaries stay explicit:

- structural parsing and routing stay in normalization code
- durable lexical policy lives in the built-in profile layers
- app- or user-owned pronunciation policy lives in stored custom profiles
- persistence, active-profile identity, and selected summary configuration live in `Runtime`
- provider-specific summary execution stays opt-in and async so deterministic normalization remains the default behavior

## Remaining refinement work

The next real package work is no longer “finish the split.” It is:

- tightening profile ergonomics and documentation
- improving structured source normalization, starting with Swift
- keeping the normalization boundaries honest as the package grows
- preserving a clean file layout as features land so oversized files do not quietly grow back

## Maintainer checklist

When adding new work:

- prefer extending the current role-based source layout instead of growing a new oversized catch-all file
- keep `semanticCore` focused on always-on shipped semantics and keep built-in style presets focused on presentation policy
- keep normalization-entry routing and structural parsing in normalization code
- keep persistence-path and active-profile decisions in runtime code
- update README, roadmap, and maintainer notes together when the public API or ownership model changes
