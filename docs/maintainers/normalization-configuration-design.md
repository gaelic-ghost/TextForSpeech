# Normalization Policy and Context Design

This note records the M10 design direction for caller-owned normalization
policy, request context, and format detection. It is a design checkpoint before
implementation, not a completed API contract.

## Goal

Callers need one explicit way to control how noisy developer text becomes
speech-safe text, while request-local facts stay in one request context. The
immediate surfaces are:

- URL normalization
- markdown-link normalization
- file-path normalization and repeated-path compaction
- Codex hook payload cleanup
- request-local path context such as `cwd` and `repoRoot`
- outer text-format detection and nested source-format detection

The current defaults are deterministic and useful, but they are always on. That
works for general speech output and is too blunt for hook payloads where useful
messages, paths, command output, and failure context can be mixed with metadata
that should not be read aloud.

## Design Rules

This should be a durable building-block change, not a second pipeline.

Normalization behavior should travel through the existing normalization
entrypoints as explicit policy:

- `TextForSpeech.Normalize.text(...)`
- `TextForSpeech.Normalize.source(...)` when summarized source re-enters text normalization
- `runtime.normalize.text(...)`
- `runtime.normalize.source(...)` when summarized source re-enters text normalization

Request facts should travel through `TextForSpeech.RequestContext`. `cwd` and
`repoRoot` are facts about the caller's current request environment, not facts
about the input's format. Keeping them in `RequestContext` lets path speaking,
path compaction, hook cleanup, and future request-aware rules share the same
source of truth.

`InputContext` should not become the policy container. After `cwd` and
`repoRoot` move to `RequestContext`, its remaining fields are `textFormat` and
`nestedSourceFormat`; both should be replaced by detection or removed before the
public surface grows around them.

The Swift API rule being applied is clarity at the use site. The
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
prefer clear use sites and defaulted parameters over a family of similar methods
when the common call should stay simple and the advanced call needs explicit
policy.

## Proposed Public Shape

Use one policy value with conservative defaults:

```swift
public extension TextForSpeech {
    struct NormalizationPolicy: Codable, Sendable, Equatable {
        public var urlPolicy: URLPolicy
        public var markdownLinkPolicy: MarkdownLinkPolicy
        public var filePathPolicy: FilePathPolicy
        public var requestMode: RequestMode

        public static let `default`: Self
        public static let codexHook: Self
    }
}
```

`RequestContext` should carry request facts, including path context:

```swift
TextForSpeech.RequestContext(
    source: "codex",
    app: "SpeakSwiftly",
    project: "TextForSpeech",
    cwd: "/workspace/SpeakSwiftly",
    repoRoot: "/workspace/SpeakSwiftly"
)
```

The public normalize methods should accept a trailing defaulted policy argument:

```swift
try await TextForSpeech.Normalize.text(
    hookPayload,
    requestContext: requestContext,
    policy: .codexHook
)
```

Common calls should continue to need no policy value. Advanced calls should
read clearly at the use site, and callers should not have to create a context
object just to choose behavior.

## Context Ownership

`RequestContext` should own:

- request origin: `source`, `app`, `agent`, `project`, and `topic`
- request attributes: freeform string metadata that does not earn a stable field
- request environment: `cwd` and `repoRoot`, normalized the same way paths are
  normalized today

Path-aware normalization should read path context from `RequestContext`. This
includes standalone path speaking, file-reference speaking, inline-code path
speaking, and repeated-path compaction.

`InputContext` should be removed once no durable input-local facts remain. If a
temporary migration step is needed, keep it small and explicit in the
implementation branch rather than designing new API around it.

## Format Detection

`textFormat` and `nestedSourceFormat` are not request facts. They currently act
as caller-provided hints for routing normalization, but both can be narrowed or
removed.

Outer text format already has a detection path through
`TextForSpeech.Normalize.detectTextFormat(in:)`. The first implementation pass
should make the text normalizer rely on detection by default and avoid exposing
`InputContext.textFormat` as the way to force a branch. If a future caller proves
that forced text routing is needed, prefer an explicit normalize argument over a
context field, because the call site should say that the caller is overriding
detection.

Nested source format should be detected per embedded code span instead of stored
as one context-wide value. Markdown fenced code has the strongest signal: the
opening fence can carry an info string such as `swift`, `python`, or `rust`.
The markdown pass should map known fence language identifiers to `SourceFormat`,
route that block through the source normalizer, and fall back to generic spoken
code for unlabeled or unknown fences.

Inline code usually has no language signal. The first implementation pass should
keep the current useful heuristics for file references, URLs, and paths, then
use generic spoken code for the rest. That preserves the current behavior
without pretending a request-wide nested language is reliable for mixed prose.

The package may keep `TextForSpeech.Normalize.detectTextFormat(in:)` as a public
preflight and diagnostics helper. Source-format detection for nested markdown
should start as an internal helper unless a concrete caller needs to inspect it.

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

1. Move `cwd` and `repoRoot` from `InputContext` into `RequestContext` and
   update path-speaking and path-compaction call sites.
2. Replace `InputContext.textFormat` with outer text-format detection in the
   text normalizer.
3. Replace `InputContext.nestedSourceFormat` with per-fence nested source
   detection and generic inline-code fallback.
4. Remove `InputContext` if no input-local facts remain.
5. Add `NormalizationPolicy` and thread it through public normalize methods and
   runtime normalization methods as a trailing defaulted argument.
6. Teach URL, markdown-link, and path passes to read policy from the resolved
   policy value.
7. Add `RequestMode.codexHook` with a small pre-normalization cleanup pass.
8. Add representative hook payload fixtures and tests.
9. Update README, roadmap, maintainer docs, and release notes together.

## Non-Goals

- Do not add a separate `Normalize.codexHook(...)` pipeline in the first pass.
- Do not persist normalization policy in `Runtime` until a real caller needs
  stored per-runtime policy.
- Do not expose arbitrary regex cleanup rules in the first implementation pass.
- Do not change the current default behavior for ordinary callers.
- Do not keep both `InputContext` and `RequestContext` as overlapping context
  objects after the migration unless Gale explicitly approves that compromise.
