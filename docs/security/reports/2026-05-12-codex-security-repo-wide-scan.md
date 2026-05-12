# TextForSpeech Codex Security Repository-Wide Scan

Scan date: 2026-05-12

Scan target: TextForSpeech repository

Commit: `183d7ef`

## Summary

One reportable low-severity finding survived validation and attack-path analysis. No critical, high, or medium findings were found.

The strongest positive result is that the optional `.codexExec` summarization path uses `Process` with argument arrays instead of shell interpolation, so the audit did not find command injection there. The surviving issue is availability-oriented: the parent waits for `codex exec` to exit before draining stdout and stderr, which can deadlock when the child fills a pipe.

The scan also identified a follow-up text-boundary concern for summary providers: summary-aware normalization can send raw caller text into a selected summarizer when callers pass `summarize: true`. That behavior is explicit and opt-in, so it was not reported as a vulnerability, but it should be documented as a redaction and provider-selection boundary for downstream consumers.

## Finding: `.codexExec` Summarization Can Hang When Child Output Fills a Pipe

- Priority: P3
- Severity: low
- Confidence: high for the local hang; medium for attacker reachability
- CWE: CWE-400 Uncontrolled Resource Consumption
- Affected lines:
  - `Sources/TextForSpeech/API/NormalizationAPI.swift:16-18`
  - `Sources/TextForSpeech/Normalization/TextSummarizer.swift:43-48`
  - `Sources/TextForSpeech/Normalization/TextSummarizer.swift:57-89`

### Summary

`TextForSpeech.Normalize.text(... summarize: true, summarizationProvider: .codexExec)` eventually calls `runCodexExec`. That function starts `codex exec`, writes the prompt to stdin, closes stdin, then calls `process.waitUntilExit()` before reading stdout or stderr.

If the child writes enough stdout or stderr to fill the pipe before it exits, the child blocks waiting for the parent to read, while the parent blocks waiting for the child to exit. The result is a stuck normalization request.

### Validation

Validation used a disposable SwiftPM harness outside the repository. The harness imported the checked-out TextForSpeech package and placed a fake `codex` executable first on `PATH`. The fake executable wrote 200 KB to stdout and flushed.

The harness built successfully, then remained running past 20 seconds. Process inspection showed both the probe parent and fake `codex` child still alive. They were killed after confirmation.

### Reachability Analysis

This repository is an in-process library and does not expose HTTP, MCP, CLI, or daemon ingress. A realistic attacker path depends on a downstream consumer enabling `.codexExec` summarization for text controlled by a lower-privileged or remote actor.

The issue is still in scope because `.codexExec` is a public summarization provider and summarization is an explicitly modeled trust boundary. The provider is opt-in and `summarize` defaults to false, which limits likelihood and severity.

### Attack Path

1. A downstream consumer selects `.codexExec` and calls summary-aware normalization.
2. Attacker-controlled text influences the prompt sent to `codex exec`.
3. `codex exec` writes enough output or error text to fill a pipe.
4. TextForSpeech remains blocked in `waitUntilExit()` because stdout and stderr are only read afterward.
5. The host request or worker remains stuck until externally terminated.

### Remediation

- Drain stdout and stderr while the child process is running.
- Add a timeout.
- Terminate the child on timeout or task cancellation.
- Cap collected output.
- Add a regression test with a fake `codex` executable that writes more than the pipe buffer and assert the call fails boundedly instead of hanging.

## Follow-Up: Summary Provider Text Boundary

### Why It Matters

Summary-aware normalization is deterministic by default because `summarize` defaults to false. When callers enable summarization, caller-provided text may leave the local deterministic normalization path and enter the selected provider.

The `.openAIResponses` provider sends caller text to the OpenAI Responses API using `OPENAI_API_KEY` from the process environment. The `.codexExec` provider hands caller text to a local Codex CLI process, while `.foundationModels` sends it to the platform model session when available.

### Disposition

This was not reported as a vulnerability because provider selection and the `summarize` flag are explicit caller choices, and the API does not imply that TextForSpeech redacts secrets before summarization. It remains a roadmap item because downstream consumers need clear guidance that they own redaction and provider selection before enabling live providers for untrusted or sensitive text.

### Follow-Up Work

- Document that summary providers may receive raw caller text.
- Decide whether TextForSpeech should enforce size limits before provider calls.
- Decide whether provider-specific guidance should mention prompt-boundary risks, redaction expectations, and the lack of package-owned secret sanitization.
- Keep any future sanitization behavior explicit and test-backed so deterministic normalization stays predictable.

## Coverage Closure

| Row | Disposition | Reason |
| --- | --- | --- |
| RW-001 | reportable | `.codexExec` pipe backpressure hang survived validation. |
| RW-002 | suppressed | `.openAIResponses` is explicit opt-in, `summarize` defaults false, `store: false` is sent, and no secret logging was found. |
| RW-003 | suppressed | Markdown and SwiftSoup parser rows had no advisory hit and no concrete local malformed-input crash or resource-exhaustion proof. |
| RW-004 | suppressed | Default persistence path is package-derived; explicit `.file(URL)` is caller-owned configuration. |
| RW-005 | not applicable | Persisted JSON uses typed Codable values, not dynamic class or object construction. |
| RW-006 | not applicable | Replacement rules transform strings only and do not reach eval, shell, SQL, or rendering sinks. |
| RW-007 | suppressed | Release scripts are maintainer-operated, quote arguments, gate SemVer tags, and require clean state. |

## Verification

- GitHub advisory checks returned no advisories for `swift-markdown`, `swift-cmark`, or `SwiftSoup`.
- Disposable validation harness reproduced the pipe hang and was killed after confirmation.
- `swift test` initially failed due to a stale SwiftPM module-cache path from the older checkout location.
- `swift package clean`
- `swift test` passed after cleaning, with 148 Swift Testing tests.
