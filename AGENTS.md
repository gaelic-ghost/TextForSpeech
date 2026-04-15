# AGENTS.md

## Repository Identity

- `TextForSpeech` is a plain Swift Package Manager repository. Treat `Package.swift` as the source of truth for package structure, products, targets, platforms, and language mode.
- Prefer `swift package` subcommands for structural package work when they cover the change. Keep manual `Package.swift` edits minimal and intentional when the CLI does not cover the needed configuration.
- Validate package changes with `swift build` and `swift test` from the repository root.
- Keep Swift build and test processes serialized. Do not start a second SwiftPM or Xcode build or test command while another one is still running.

## Project-Specific Priorities

- Keep `TextForSpeech` as the shared source of truth for speech-safe normalization of code-heavy text and profile-driven pronunciation overrides.
- Preserve the namespace-first public surface centered on `TextForSpeech.Normalize` and `TextForSpeech.Runtime`.
- Prefer complete cleanup passes over incremental compatibility layers. Do not leave legacy shims, duplicate codepaths, or transitional wrappers behind unless the user explicitly approves that compromise.
- Keep operator-facing errors, warnings, and log messages concrete, descriptive, and human-readable.

## Architecture Boundaries

- Keep structural parsing, routing, markdown handling, format detection, and normalization pipeline control in `Sources/TextForSpeech/Normalization`.
- Keep durable built-in lexical policy in the built-in profile layers and related model definitions under `Sources/TextForSpeech/Models`.
- Keep stored-profile ownership, active-profile identity, persistence, and runtime state repair in `Sources/TextForSpeech/Runtime`.
- Keep parsing helpers in normalization only when they materially support the production normalization pipeline. Do not reintroduce a separate forensic surface unless the package regains a real analysis use case that earns its own API.
- Before adding a new abstraction, wrapper, helper type, or dependency, make sure it removes a real maintenance or modeling problem in this package instead of just making the code look more architectural.

## Swift Coding Guidance

- Prefer the simplest correct Swift that is easiest to read, reason about, and maintain.
- Prefer explicit, stable, source-of-truth naming across models, runtime state, and public APIs when the meaning has not changed.
- Prefer synthesized conformances, memberwise initialization, and framework defaults over handwritten boilerplate.
- Do not add DTO layers, domain conversion layers, coordinator types, or extra protocol surfaces unless a concrete boundary requires them.
- Keep the code Swift 6 compliant with strict concurrency checking enabled.
- Prefer modern structured concurrency when it makes the control flow clearer.
- Prefer pure Swift solutions and first-party or top-tier Swift ecosystem packages when they clearly simplify the code.

## Testing and Tooling

- Use Swift Testing (`import Testing`) as the default test framework. Do not introduce XCTest unless an external constraint requires it.
- Keep formatting and linting choices consistent with the existing repository direction. If formatter or linter config is added or changed, prefer clear maintainable rule intent over style churn.
- When touching normalization or runtime behavior, add or update focused tests in `Tests/TextForSpeechTests` in the same pass.

## Documentation Alignment

- Keep `README.md`, `ROADMAP.md`, and the maintainer notes under `docs/maintainers/` aligned with the real package architecture and public API.
- When the public API, runtime model, ownership boundaries, or source layout changes, update the relevant docs in the same change instead of leaving migration notes to drift.
- Treat `AGENTS.md` as the concise repository policy surface and `docs/maintainers/` as the deeper architectural reference. When those maintainer notes become more specific, keep them current in the same pass so the two layers do not drift apart.
- Preserve checklist-style structure in `ROADMAP.md`.
- Keep release notes under `docs/releases/` factual, scoped to the tagged change, and explicit about any behavior or API shifts.

## Source Layout Expectations

- Keep source files role-focused and avoid letting catch-all files grow back.
- Prefer extending the current responsibility-based layout under `API/`, `Models/`, `Normalization/`, and `Runtime/` instead of introducing ambiguous new buckets.
- If a file starts collecting unrelated responsibilities, split it by role before adding more behavior.

## CLI Preferences

- Prefer `swift build` and `swift test` as the first-pass local verification commands.
- Use `xcodebuild` only when a task truly depends on Apple SDK or Xcode-managed behavior that SwiftPM alone does not cover.
- Keep CLI commands deterministic and reproducible.
