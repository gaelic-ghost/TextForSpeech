# Normalization Style and Context Design

This note records the M10 design direction for request context, style-owned
normalization behavior, and format detection. It is a design checkpoint before
implementation, not a completed API contract.

## Goal

Callers need clear control over how noisy developer text becomes speech-safe
text, while request-local facts stay in one request context. The immediate
surfaces are:

- URL normalization
- markdown-link normalization
- file-path normalization and repeated-path compaction
- Codex hook payload cleanup
- request-local path context such as `cwd` and `repoRoot`
- outer text-format detection and embedded-code fallback

The current defaults are deterministic and useful, but some of the behavior is
more accurately presentation style than standalone configuration. For example,
speaking every URL component, shortening paths, or omitting low-value hook
metadata is mostly a verbosity and listening-context choice.

## Design Rules

This should be a durable building-block change, not a second pipeline and not a
new `NormalizationPolicy` type.

The package already has the right behavior surfaces:

- `BuiltInProfileStyle` chooses shipped verbosity and presentation behavior.
- `Profile` and `Replacement` express reusable pronunciation and token rewrite
  behavior.
- `RequestContext` carries slim facts about the request, including `source`,
  `topic`, `cwd`, and `repoRoot`.
- parser-backed and platform-backed detectors should identify reusable token
  ranges before surrounding document format is considered.

The Swift API rule being applied is clarity at the use site. The
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
prefer clear use sites and defaulted parameters over a family of similar methods
when the common call should stay simple and the advanced call needs explicit
behavior.

## Context Ownership

`RequestContext` should own:

- request origin: broad `source` plus human-facing `topic`
- request attributes: freeform string metadata that does not earn a stable field
- request environment: `cwd` and `repoRoot`, normalized the same way paths are
  normalized today

Path-aware normalization should read path context from `RequestContext`. This
includes standalone path speaking, file-reference speaking, inline-code path
speaking, and repeated-path compaction.

`InputContext` has been removed. The previous text-format and nested-source
hints are no longer caller-provided behavior knobs. `cwd` and `repoRoot` now
live on `RequestContext`, and text normalization uses detection plus generic
embedded-code fallback instead of request-wide source hints.

## Style and Replacement Review

Do not add `NormalizationPolicy`. Review and adjust the existing style/profile
model instead.

The review pass should answer:

- which URL, markdown-link, and path behaviors belong to `.compact`,
  `.balanced`, and `.explicit`
- whether those behaviors should be modeled as existing `Replacement` rules,
  new `Replacement.Transform` cases, or small normalizer decisions keyed from
  the active built-in style
- whether any future non-Codex-specific cleanup belongs in shipped styles or
  should stay downstream
- whether downstream apps should persist only the active built-in style through
  `Runtime`, or persist app-specific request preferences outside this package

Today, `Runtime` already persists the active built-in style through
`runtime.style.setActive(to:)` and `PersistedState.builtInStyle`. Direct
`TextForSpeech.Normalize` calls use a per-call `style:` parameter with
`.balanced` as the default and do not persist anything by themselves.

## Format Detection

Text format and embedded source format are not request facts. Text-format
routing is detection-owned, and embedded code in mixed text uses local
structural detection plus generic code speech unless the whole input enters the
explicit source-normalization API.

Format detection must not be the main way reusable tokens are found. URLs,
addresses, links, dates, phone numbers, paths, and similar spans need the same
speech treatment no matter whether the surrounding document is prose, markdown,
HTML, CLI output, logs, or a Codex hook payload. Detect those token ranges first,
then let document-structure detection decide how to traverse larger containers.

Use `AttributedString` as the internal marked-text carrier for those detections.
Apple's `AttributedString` model already represents contiguous ranges with the
same attributes as runs, supports system-defined scopes such as links, and lets
the package define its own custom attribute keys for developer token kinds. That
gives the normalizer one place to mark "this range is a URL," "this range is a
file reference," or "this range is a CLI flag" before style-specific speech
rules decide what to do with the marked runs.

The intended detection model is:

1. Use `NSDataDetector` for platform-supported semantic token ranges such as
   links, addresses, dates, and phone numbers. These detections should feed the
   same token transforms regardless of surrounding text format.
2. Use path and code-token detectors for developer-specific spans that
   `NSDataDetector` does not own, such as file paths, file-line references, CLI
   flags, identifiers, issue references, measured values, and scalar shorthands.
3. Use parser-backed markdown structure for markdown containers. Prefer
   `swift-markdown` when the package needs headings, lists, links, inline code,
   fenced code blocks, and fence info as source-aware nodes.
4. Use parser-backed HTML structure for HTML containers. Prefer an HTML parser
   such as SwiftSoup when the package needs DOM-aware extraction or link/text
   behavior instead of regex-like tag checks.
5. Use lightweight CLI and log line classifiers for line-oriented formats that
   are not covered by platform token detection or document parsers.
6. Treat plain prose as the fallback. Ambiguous input should stay plain, while
   detected token ranges inside that prose still get token-level normalization.

`TextForSpeech.Normalize.detectTextFormat(in:)` can remain as a public
diagnostics/preflight helper, but it should not be the source of truth for
whether URL-like, address-like, link-like, or path-like tokens are normalized.
Those token ranges should be normalized because they were detected as tokens,
not because the whole input was classified as a particular text format.

The current implementation still uses a conservative ordered classifier for the
outer `TextFormat` value, but markdown and HTML structure checks now go through
the package-owned `swift-markdown` and SwiftSoup parser helpers instead of
regex-like document detection. Markdown code blocks, inline code, links,
priority list items, and plain priority paragraphs are normalized through
`swift-markdown` traversal. HTML currently has no custom normalization helper
beyond SwiftSoup-backed structure detection. The remaining transition work is
to move reusable token normalization onto the token-first detection surface.

Embedded code in mixed text should not use one context-wide source format.
Markdown fenced code and inline code should stay in the generic embedded-code
path unless the whole input enters the explicit source-normalization API.

Inline code usually has no language signal. The first implementation pass should
keep the current useful heuristics for file references, URLs, and paths, then
use generic spoken code for the rest. That preserves the current behavior
without pretending a request-wide nested language is reliable for mixed prose.

The package may keep `TextForSpeech.Normalize.detectTextFormat(in:)` as a public
preflight and diagnostics helper. Do not add public nested source-format
detection unless a concrete caller needs to inspect that signal separately.

## URL, Link, and Path Behavior

URL, markdown-link, and path handling should be reviewed as style/verbosity
behavior first.

Possible style direction:

- `.compact`: preserve or shorten more aggressively when visual context is
  likely still available. URLs may become host-only or omitted when low-value.
  Paths may prefer basenames after the first contextual mention.
- `.balanced`: keep the current general-purpose behavior unless tests show a
  clear speech problem. URLs and links remain useful, and path compaction stays
  context-aware.
- `.explicit`: favor audio-first signposting. URLs, links, file references, CLI
  flags, and paths should retain enough labels that the listener understands
  what kind of token they are hearing.

If these choices need reusable caller customization beyond the shipped style
presets, prefer extending `Profile` and `Replacement` before adding any new
top-level behavior model.

## Codex Hook Cleanup

Codex-specific hook cleanup is downstream-owned for now. Hook scripts should
remove or reshape Codex-only payload metadata before text enters this package.
Do not add package-owned Codex hook parsing while that downstream boundary is
working.

If custom hook filtering becomes necessary later, reopen the package boundary
only after real examples prove downstream hook-script cleanup is the wrong
ownership model. That review should identify:

- which metadata fields are never useful speech content
- which fields preserve operator-facing messages, commands, paths, exit codes,
  check names, and failure context
- whether any cleanup is generic enough to belong in shipped style presets
- which parts, if any, belong in shipped style presets

## Implementation Order

1. Remove the previous `InputContext.textFormat` hint entirely and keep outer
   text-format routing detection-owned.
2. Keep path-speaking and path-compaction call sites reading `cwd` and
   `repoRoot` from `RequestContext`.
3. Remove `InputContext.nestedSourceFormat` and use generic embedded-code
   fallback for mixed-text code spans.
4. Remove `InputContext` if no input-local facts remain.
5. Review `.compact`, `.balanced`, and `.explicit` against URL, markdown-link,
   and path behavior.
6. Adjust style presets, replacement transforms, and tests according to that
   review.
7. Keep Codex-specific hook parsing downstream unless real examples prove a
   package-owned generic cleanup belongs here.
8. Update README, roadmap, maintainer docs, and release notes together.

## Non-Goals

- Do not add `NormalizationPolicy`.
- Do not add a separate `Normalize.codexHook(...)` pipeline in the first pass.
- Do not expose arbitrary regex cleanup rules in the first implementation pass.
- Do not change the current default behavior for ordinary callers without a
  focused style review and tests.
- Do not reintroduce overlapping input and request context objects unless Gale
  explicitly approves that compromise.
