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
- outer text-format detection and nested source-format detection

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
- `RequestContext` carries facts about the request, including the planned
  `cwd` and `repoRoot` move.
- parser-backed and platform-backed detectors should identify reusable token
  ranges before surrounding document format is considered.

The Swift API rule being applied is clarity at the use site. The
[Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/)
prefer clear use sites and defaulted parameters over a family of similar methods
when the common call should stay simple and the advanced call needs explicit
behavior.

## Context Ownership

`RequestContext` should own:

- request origin: `source`, `app`, `agent`, `project`, and `topic`
- request attributes: freeform string metadata that does not earn a stable field
- request environment: `cwd` and `repoRoot`, normalized the same way paths are
  normalized today

Path-aware normalization should read path context from `RequestContext`. This
includes standalone path speaking, file-reference speaking, inline-code path
speaking, and repeated-path compaction.

`InputContext` should not become a behavior container. The previous
`InputContext.textFormat` hint has been removed entirely; callers should not
provide a text-format hint. After `cwd` and `repoRoot` move to
`RequestContext`, the remaining `nestedSourceFormat` field should be replaced
by per-fence detection or removed before the public surface grows around it.

## Style and Replacement Review

Do not add `NormalizationPolicy`. Review and adjust the existing style/profile
model instead.

The review pass should answer:

- which URL, markdown-link, and path behaviors belong to `.compact`,
  `.balanced`, and `.explicit`
- whether those behaviors should be modeled as existing `Replacement` rules,
  new `Replacement.Transform` cases, or small normalizer decisions keyed from
  the active built-in style
- whether Codex hook cleanup should be a style-aware text mode, a request-origin
  behavior keyed from `RequestContext.source`, or a small explicit normalize
  option
- whether downstream apps should persist only the active built-in style through
  `Runtime`, or persist app-specific request preferences outside this package

Today, `Runtime` already persists the active built-in style through
`runtime.style.setActive(to:)` and `PersistedState.builtInStyle`. Direct
`TextForSpeech.Normalize` calls use a per-call `style:` parameter with
`.balanced` as the default and do not persist anything by themselves.

## Format Detection

Text format and `nestedSourceFormat` are not request facts. Text-format routing
is detection-owned; `nestedSourceFormat` remains a temporary migration target
until per-fence detection replaces it.

Format detection must not be the main way reusable tokens are found. URLs,
addresses, links, dates, phone numbers, paths, and similar spans need the same
speech treatment no matter whether the surrounding document is prose, markdown,
HTML, CLI output, logs, or a Codex hook payload. Detect those token ranges first,
then let document-structure detection decide how to traverse larger containers.

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
regex-like document detection. That is still only a transition state: the next
implementation pass should introduce the token-first detection surface and then
replace remaining markdown and HTML normalization helpers with parser-backed
traversal wherever structured extraction is needed.

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

Codex hook cleanup should start as a focused review item, not a separate
pipeline.

The review should identify real hook payload examples and decide:

- which metadata fields are never useful speech content
- which fields preserve operator-facing messages, commands, paths, exit codes,
  check names, and failure context
- whether hook cleanup should be selected explicitly, inferred from
  `RequestContext.source == "codex-hook"`, or left to a downstream caller before
  text enters this package
- which parts, if any, belong in shipped style presets

If custom hook filtering becomes necessary later, add it only after real hook
examples prove that style/profile/replacement behavior cannot cover the need.

## Implementation Order

1. Move `cwd` and `repoRoot` from `InputContext` into `RequestContext` and
   update path-speaking and path-compaction call sites.
2. Remove the previous `InputContext.textFormat` hint entirely and keep outer
   text-format routing detection-owned.
3. Replace `InputContext.nestedSourceFormat` with per-fence nested source
   detection and generic inline-code fallback.
4. Remove `InputContext` if no input-local facts remain.
5. Review `.compact`, `.balanced`, and `.explicit` against URL, markdown-link,
   path, and hook cleanup behavior.
6. Adjust style presets, replacement transforms, and tests according to that
   review.
7. Add representative hook payload fixtures and tests only after hook ownership
   is settled.
8. Update README, roadmap, maintainer docs, and release notes together.

## Non-Goals

- Do not add `NormalizationPolicy`.
- Do not add a separate `Normalize.codexHook(...)` pipeline in the first pass.
- Do not expose arbitrary regex cleanup rules in the first implementation pass.
- Do not change the current default behavior for ordinary callers without a
  focused style review and tests.
- Do not keep both `InputContext` and `RequestContext` as overlapping context
  objects after the migration unless Gale explicitly approves that compromise.
