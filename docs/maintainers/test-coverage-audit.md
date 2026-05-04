# Test Coverage Audit

## Current status

The first coverage, parsing utility, persistence, and format-detection passes raised the default Swift Testing suite from 108 tests to 133 tests and moved measured line coverage from 84.24% to 90.55%.

The strongest current coverage is the deterministic normalization path:

- public text and source normalization entrypoints
- runtime text and source normalization wrappers
- built-in style composition
- custom replacement application
- runtime profile persistence and migration
- operator-facing runtime, persistence, and summary error descriptions

The `.test` summarization provider now covers the summary-aware public path without live network, process, or Apple framework dependencies. It returns input unchanged, then lets the normal text or source normalization path continue.

Request-context preface behavior is covered through public text and source
normalization entrypoints. Path-only context is covered separately so `cwd` and
`repoRoot` keep serving path shortening without adding spoken metadata.

## Remaining significant gaps

### Live summary providers

The live summary providers remain intentionally outside the default suite:

- `.codexExec`
- `.openAIResponses`
- `.foundationModels`

These should be covered by opt-in integration tests or executable examples that are gated by credentials, platform support, and local tool availability. Ordinary `swift test` should not invoke Codex, OpenAI, or Foundation Models implicitly.

### Parsing utilities

The first parsing utility pass removed helpers that production code no longer called instead of keeping them alive with artificial tests. The remaining helper surface now has focused coverage for inline code spans, markdown links, markdown headings, and Natural Language word tokenization.

The pass also fixed a malformed-link parser bug where an earlier broken bracket sequence could greedily swallow a later valid markdown link.

Remaining useful coverage targets:

- additional malformed markdown link shapes with nested parentheses or escaped characters
- Unicode-heavy word-breaking behavior used by speech helpers
- markdown headings with unusual indentation or heading levels beyond ordinary authoring patterns

### Format detection

`FormatDetection.swift` now has happy-path coverage plus a first false-positive pass for prose that happens to contain source-language words, unmatched markdown punctuation, incomplete HTML tags, one-item markdown-like lists, log severity words in lowercase prose, and `>` block quote prose that should not be mistaken for CLI output.

Remaining useful coverage targets:

- additional shell prompt shapes, especially Windows prompts and multi-line terminal transcripts
- log-like prose with uppercase words that are not structured log levels
- markdown block quote handling if the package later adds dedicated block quote normalization

### Persistence I/O failure behavior

Error descriptions are covered, unsupported persisted-state versions are covered, and real filesystem failure tests now exercise invalid JSON decode failures, directory-backed read failures, blocked parent-directory creation, and directory-backed write failures.

Remaining useful coverage targets:

- read failures when a path exists but is not readable, if the test can stay reliable on macOS without brittle permission assumptions
- additional migration fixtures if the persisted archive shape changes

## Roadmap-backed follow-up work

The next normalization design work is configurable policy for URL, markdown-link, and path handling. That should let callers choose whether these surfaces are spoken verbosely, shortened, preserved, or filtered.

Codex-specific hook cleanup is downstream-owned for now. Hook scripts should pre-clean payload metadata before text enters this package; package-owned cleanup should be reopened only if real examples prove downstream cleanup is the wrong boundary.
