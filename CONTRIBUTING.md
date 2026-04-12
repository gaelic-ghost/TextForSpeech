# Contributing

## Workflow

`TextForSpeech` is a plain Swift Package Manager repository. Treat `Package.swift` as the source of truth for package structure, products, targets, platforms, and language mode.

Prefer `swift package` subcommands for structural package changes when they cover the work. Keep manual manifest edits small and intentional when the CLI does not cover the needed configuration.

Validate changes from the repository root with:

```bash
swift build
swift test
```

Keep Swift build and test processes serialized. Do not start a second SwiftPM or Xcode build or test command while another one is still running.

## Coding Expectations

Prefer the simplest correct Swift that is easiest to read, reason about, and maintain. Keep stable, source-of-truth naming across models, runtime state, and public APIs when the meaning has not changed.

Do not leave compatibility shims, duplicate codepaths, or transitional wrappers behind unless the maintainer explicitly approves that compromise. When touching normalization or runtime behavior, update focused tests in `Tests/TextForSpeechTests` in the same pass.

## Architecture Boundaries

Keep structural parsing, routing, markdown handling, format detection, and normalization pipeline control in `Sources/TextForSpeech/Normalization`.

Keep durable built-in lexical policy in `Sources/TextForSpeech/Models`.

Keep stored-profile ownership, active-profile identity, persistence, and runtime state repair in `Sources/TextForSpeech/Runtime`.

Keep forensic helpers honest about what they measure and separate from production normalization unless a primitive is genuinely shared.

## Documentation

Keep `README.md`, `ROADMAP.md`, and the maintainer notes under `docs/maintainers/` aligned with the real package architecture and public API.

Treat `AGENTS.md` as the concise repository policy surface and `docs/maintainers/` as the deeper architectural reference. When public API, runtime model, ownership boundaries, or source layout changes, update the relevant docs in the same change.

Keep release notes under `docs/releases/` factual and scoped to the tagged change.
