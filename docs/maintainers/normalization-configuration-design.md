# Normalization Configuration Design

This note records the M10 design direction for caller-owned normalization policy.
It is a design checkpoint before implementation, not a completed API contract.

## Goal

Callers need one explicit way to control how noisy developer text becomes
speech-safe text. The immediate surfaces are:

- URL normalization
- markdown-link normalization
- file-path normalization and repeated-path compaction
- Codex hook payload cleanup

The current defaults are deterministic and useful, but they are always on. That
works for general speech output and is too blunt for hook payloads where useful
messages, paths, command output, and failure context can be mixed with metadata
that should not be read aloud.

## Design Rule

This should be a durable building-block change, not a second pipeline.

The configuration should travel through the existing normalization entrypoints:

- `TextForSpeech.InputContext`
- `TextForSpeech.Normalize.text(...)`
- `TextForSpeech.Normalize.source(...)` when summarized source re-enters text
  normalization
- `runtime.normalize.text(...)`
- `runtime.normalize.source(...)` when summarized source re-enters text
  normalization

The Swift API rule being applied is clarity at the use site. The
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
prefer clear use sites and defaulted parameters over a family of similar methods
when the common call should stay simple and the advanced call needs explicit
policy.

## Proposed Public Shape

Use one configuration value with conservative defaults:

```swift
public extension TextForSpeech {
    struct NormalizationConfiguration: Codable, Sendable, Equatable {
        public var urlPolicy: URLPolicy
        public var markdownLinkPolicy: MarkdownLinkPolicy
        public var filePathPolicy: FilePathPolicy
        public var requestMode: RequestMode

        public static let `default`: Self
        public static let codexHook: Self
    }
}
```

`InputContext` should carry the value:

```swift
TextForSpeech.InputContext(
    textFormat: .markdown,
    normalizationConfiguration: .codexHook
)
```

The public normalize methods should also accept a trailing defaulted argument so
callers that do not already need an `InputContext` do not have to construct one:

```swift
try await TextForSpeech.Normalize.text(
    hookPayload,
    normalizationConfiguration: .codexHook
)
```

When both are present, the explicit method argument should win over the
configuration stored in `InputContext`. That keeps call-site overrides local and
easy to reason about.

## URL Policy

URL policy controls standalone URLs and URL-shaped tokens.

Proposed cases:

- `spoken`: current default; convert URLs into speech-friendly words.
- `hostOnly`: keep the domain or host as speech-safe text and omit low-value
  query strings or fragments.
- `preserved`: leave the original URL text in place for downstream consumers
  that want raw text.
- `omitted`: remove standalone URLs entirely.

The first implementation pass should keep `.spoken` as the default.

## Markdown-Link Policy

Markdown-link policy controls `[label](destination)` handling.

Proposed cases:

- `labelAndDestination`: current default; preserve useful label and destination
  information in speech-safe form.
- `labelOnly`: speak the label and omit the destination.
- `destinationOnly`: speak only the destination.
- `preserved`: leave the original markdown syntax in place.
- `omitted`: remove the link entirely.

For Codex hook mode, `labelOnly` is likely the best default because hooks often
include machine URLs that add little value when read aloud.

## File-Path Policy

File-path policy controls path speaking and repeated-path compaction.

Proposed cases:

- `contextual`: current default; speak paths with `cwd`, `repoRoot`, and
  repeated-path context.
- `basenameOnly`: speak only the final path component.
- `preserved`: leave path text unchanged.
- `omitted`: remove paths.

Repeated-path compaction should be a sub-option rather than a separate pipeline:

```swift
public var compactsRepeatedPaths: Bool
```

`contextual` with compaction enabled should remain the default.

## Request Mode

Request mode controls request-shape cleanup before ordinary normalization runs.

Proposed cases:

- `standard`: current behavior; no request-shape filtering before the normal
  text pipeline.
- `codexHook`: filter low-value hook metadata, then run the same normalizer with
  the configured URL, link, and path policy.

Codex hook filtering should start with stable, documented defaults:

- remove known metadata headers and fields that are not useful speech content
- preserve operator-facing messages
- preserve command names and command output summaries
- preserve paths through the configured file-path policy
- preserve failure context such as exit codes, check names, and error messages

The configurable part should be the policy value, not a pile of stringly typed
filters in user code. If custom filtering becomes necessary later, add it as a
small explicit rule model after real hook examples prove the need.

## Implementation Order

1. Add `NormalizationConfiguration` and thread it through `InputContext`.
2. Update public normalize methods and runtime normalization methods with a
   trailing defaulted `normalizationConfiguration` argument.
3. Teach URL, markdown-link, and path passes to read policy from the resolved
   configuration.
4. Add `RequestMode.codexHook` with a small pre-normalization cleanup pass.
5. Add representative hook payload fixtures and tests.
6. Update README, roadmap, maintainer docs, and release notes together.

## Non-Goals

- Do not add a separate `Normalize.codexHook(...)` pipeline in the first pass.
- Do not persist normalization configuration in `Runtime` until a real caller
  needs stored per-runtime policy.
- Do not expose arbitrary regex cleanup rules in the first implementation pass.
- Do not change the current default behavior for ordinary callers.
