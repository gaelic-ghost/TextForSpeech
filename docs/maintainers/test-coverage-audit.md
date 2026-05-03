# Test Coverage Audit

## Current status

The first coverage, parsing utility, and persistence passes raised the default Swift Testing suite from 108 tests to 127 tests and moved measured line coverage from 84.24% to 88.79%.

The strongest current coverage is the deterministic normalization path:

- public text and source normalization entrypoints
- runtime text and source normalization wrappers
- built-in style composition
- custom replacement application
- runtime profile persistence and migration
- operator-facing runtime, persistence, and summary error descriptions

The `.test` summarization provider now covers the summary-aware public path without live network, process, or Apple framework dependencies. It returns input unchanged, then lets the normal text or source normalization path continue.

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

`FormatDetection.swift` has broad happy-path coverage but needs more ambiguity and false-positive tests.

Useful coverage targets:

- Swift, Python, and Rust snippets that share common words like `import`, `let`, and `use`
- shell prompts that should and should not count as CLI output
- log-like prose that should not be detected as logs
- markdown-like text that contains brackets or backticks without being real markdown
- HTML snippets with opening tags but no closing tag

### Persistence I/O failure behavior

Error descriptions are covered, unsupported persisted-state versions are covered, and real filesystem failure tests now exercise invalid JSON decode failures, directory-backed read failures, blocked parent-directory creation, and directory-backed write failures.

Remaining useful coverage targets:

- read failures when a path exists but is not readable, if the test can stay reliable on macOS without brittle permission assumptions
- additional migration fixtures if the persisted archive shape changes

## Roadmap-backed follow-up work

The next normalization design work is configurable policy for URL, markdown-link, and path handling. That should let callers choose whether these surfaces are spoken verbosely, shortened, preserved, or filtered.

The next request-shape design work is a Codex hook text mode. Hook payloads can include actionable text mixed with metadata that is poor speech content. The mode should filter low-value metadata while preserving useful failure context, paths, commands, and user-facing hook messages. The filtering policy should be configurable rather than tied to one assumed hook payload shape.
