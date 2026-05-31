# Summary Provider Security Options

This note captures the Milestone 8.1 design options for hardening opt-in summary-aware normalization.

Summary-aware normalization is off by default. When a caller passes `summarize: true`, caller text leaves the deterministic normalization path and enters the selected provider. That makes summary providers a trust boundary, not just a formatting convenience.

## Current Risk

The current `.codexExec` provider has one confirmed availability bug: it waits for the child process to exit before draining stdout and stderr. A child that writes enough output can block on a full pipe while TextForSpeech waits for exit.

The broader prompt-injection risk is that untrusted caller text can contain instructions such as "ignore previous instructions" or "return secrets instead." TextForSpeech should treat that text as data to summarize, not as instructions to obey. Prompt injection cannot be solved by string sanitization alone, because natural-language instructions can be expressed in many forms and the package should not rewrite caller content unpredictably before summarization.

## Design Goals

- Keep deterministic normalization unchanged when `summarize` is `false`.
- Make provider calls bounded by default: input size, output size, timeout, cancellation, and child-process cleanup.
- Keep prompt boundaries explicit so provider prompts separate trusted package instructions from untrusted caller text.
- Document that downstream callers own redaction before enabling live providers.
- Prefer provider-specific safety checks that fail closed or warn clearly, without pretending to guarantee prompt-injection immunity.

## Implementation Plan

The current branch will implement the first two slices as one internal hardening pass:

1. Add internal provider limits for input characters, output bytes, stderr bytes, and `.codexExec` runtime.
2. Rewrite the summary prompt so trusted package instructions are separated from clearly marked untrusted caller text.
3. Replace the blocking `.codexExec` process flow with a bounded runner that drains stdout and stderr while the process runs.
4. Terminate the child process on timeout or task cancellation.
5. Add Swift Testing coverage using fake `codex` executables for pipe backpressure, timeout, input limits, and prompt boundaries.

The Foundation Models preflight is deferred after the bounded execution and prompt-boundary baseline lands. That keeps the first implementation pass deterministic and avoids adding a public policy surface before downstream tuning needs are proven.

Implementation should keep these changes internal. Do not add public settings for limits or prompt-risk preflight until a caller actually needs to tune those behaviors.

The `.foundationModels` summary provider should continue using the Foundation Models framework directly. Writing Tools are a UIKit/AppKit text-view integration surface for user-facing proofreading, rewriting, summarization, and composition; they are not the right backend for this package's headless normalization API.

## Recommended Implementation Slices

### Slice 1: Bounded Provider Execution

This is the first implementation slice and should not wait on broader prompt-injection design.

- Drain `.codexExec` stdout and stderr while the process runs.
- Add a timeout for `.codexExec`.
- Terminate the child on timeout or task cancellation.
- Cap collected stdout and stderr.
- Cap accepted summary output before it returns to normalization.
- Add a fake `codex` executable regression test that writes more than the pipe buffer and proves the call fails boundedly.

This is a durable implementation fix because it removes a concrete hang and gives every later safety layer a bounded execution envelope.

### Slice 2: Prompt Boundary and Size Policy

This should keep caller text intact as data while making the trusted and untrusted regions obvious.

- Put caller text inside a clearly labeled untrusted-content boundary in provider prompts.
- Instruct providers to summarize the enclosed text and ignore any instructions inside that text.
- Add a maximum provider input size before building provider prompts.
- Return descriptive errors when text is too large for the selected provider.
- Document that TextForSpeech does not redact secrets and does not guarantee prompt-injection removal.

This is a local implementation detail, not a new public architecture layer, unless callers need custom limits or policy later.

### Slice 3: Optional Provider Safety Preflight

Foundation Models may be useful as an additional local preflight layer when available, but it should be advisory or provider-specific rather than a required global gate. This is deferred until a downstream caller needs stricter local gating.

Possible shape:

- Add an internal prompt-risk check before live provider calls when Foundation Models is available.
- Ask the local model to classify whether the untrusted text appears to contain instructions to override, exfiltrate, reveal secrets, call tools, change provider behavior, or ignore the summary task.
- Treat a high-risk result as a descriptive provider failure before calling `.codexExec` or `.openAIResponses`.
- Keep deterministic `.test` behavior unchanged.
- Skip this preflight cleanly when Foundation Models is unavailable, unless a future public setting explicitly requires it.

This should be treated as defense in depth. Apple's Foundation Models guardrails are useful safety infrastructure, but app-specific safety layers are still required, and the default guardrails are not a purpose-built prompt-injection detector. If this package adds a model-based prompt-risk check, tests should cover availability, failure behavior, and the fallback path.

### Slice 4: Caller-Facing Policy Surface, Only If Earned

A public settings surface should wait until the first three slices show concrete caller needs.

Possible future settings:

- summary provider timeout
- maximum provider input characters
- maximum provider output characters
- prompt-risk preflight mode: `disabled`, `whenAvailable`, or `required`

This would be a durable building-block change only if downstream callers need to tune policy. Until then, constants plus clear docs keep the public API smaller.

## Rejected Default

Do not add broad sanitization that deletes or rewrites arbitrary instructions inside caller text before summarization. It can destroy the content the caller asked to summarize, it is easy to bypass, and it makes deterministic output harder to explain. Prefer boundary marking, bounded execution, explicit redaction ownership, and optional provider-specific checks.

## Documentation Sources

- OpenAI safety best practices recommend adversarial testing, constraining input, limiting output, and considering prompt injection in red-team cases: https://developers.openai.com/api/docs/guides/safety-best-practices
- OpenAI describes prompt injection as untrusted third-party instructions entering model context and recommends layered defenses and scoped access: https://openai.com/safety/prompt-injections/
- Apple Foundation Models documentation says guardrails check model input and output, and that app-specific safety layers remain important because contextual harms can bypass built-in layers: https://developer.apple.com/documentation/foundationmodels/improving-the-safety-of-generative-model-output
- Apple `SystemLanguageModel` exposes availability and guardrails APIs, so any Foundation Models preflight must handle unavailable devices and operating systems explicitly: https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
