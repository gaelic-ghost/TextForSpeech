# AGENTS.md

Use this file for durable repo-local guidance that Codex should follow before changing code, docs, or project workflow surfaces in this Swift Package Manager repository.

## Repository Scope

### What This File Covers

This root guidance covers the `TextForSpeech` Swift package, its public API, normalization model, runtime profile persistence, tests, maintainer docs, and repo-owned maintenance scripts.

`TextForSpeech` is a plain Swift Package Manager repository. Treat `Package.swift` as the source of truth for package structure, products, targets, platforms, and language mode.

### Where To Look First

- Start with `Package.swift` for package structure, platform floors, products, targets, and Swift language mode.
- Read `Sources/TextForSpeech/API`, `Sources/TextForSpeech/Models`, `Sources/TextForSpeech/Normalization`, and `Sources/TextForSpeech/Runtime` according to the surface being changed.
- Use `Tests/TextForSpeechTests` for nearby behavior coverage when normalization or runtime behavior changes.
- Keep `README.md`, `ROADMAP.md`, and `docs/maintainers/` aligned with public API, runtime model, ownership boundaries, and source layout changes.
- Keep release notes under `docs/releases/` factual, scoped to the tagged change, and explicit about behavior or API shifts.

## Working Rules

### Change Scope

- Keep `TextForSpeech` as the shared source of truth for speech-safe normalization of code-heavy text and profile-driven pronunciation overrides.
- Preserve the namespace-first public surface centered on `TextForSpeech.Normalize` and `TextForSpeech.Runtime`.
- Prefer complete cleanup passes over incremental compatibility layers. Do not leave legacy shims, duplicate codepaths, or transitional wrappers behind unless Gale explicitly approves that compromise.
- Keep source files role-focused and avoid letting catch-all files grow back.
- If a file starts collecting unrelated responsibilities, split it by role before adding more behavior.

### Source of Truth

- Keep structural parsing, routing, markdown handling, format detection, and normalization pipeline control in `Sources/TextForSpeech/Normalization`.
- Keep durable built-in lexical policy in the built-in profile layers and related model definitions under `Sources/TextForSpeech/Models`.
- Keep stored-profile ownership, active-profile identity, persistence, and runtime state repair in `Sources/TextForSpeech/Runtime`.
- Keep parsing helpers in normalization only when they materially support the production normalization pipeline. Do not reintroduce a separate forensic surface unless the package regains a real analysis use case that earns its own API.
- Prefer explicit, stable, source-of-truth naming across models, runtime state, and public APIs when the meaning has not changed.

### Communication and Escalation

- Before adding a new abstraction, wrapper, helper type, dependency, DTO layer, domain conversion layer, coordinator type, or protocol surface, confirm that it removes a real maintenance or modeling problem in this package.
- If scope needs to widen beyond the requested normalization, runtime, docs, or maintenance surface, say so before editing.
- If Apple or SwiftPM documentation and current repo guidance disagree, stop and surface the conflict before continuing.
- Keep operator-facing errors, warnings, and log messages concrete, descriptive, and human-readable.

## Commands

### Setup

No special bootstrap command is required for normal local package work beyond having a Swift 6.2-capable toolchain available.

Use Swift Package Manager from the repository root:

```bash
swift package describe
```

### Validation

Run SwiftPM validation serially from the repository root:

```bash
swift build
swift test
```

Run repo-maintenance validation when guidance, release, tooling, or maintainer workflow files change:

```bash
sh scripts/repo-maintenance/validate-all.sh
```

### Optional Project Commands

Use the repo-owned sync and release entrypoints when those workflows are in scope:

```bash
sh scripts/repo-maintenance/sync-shared.sh
sh scripts/repo-maintenance/release.sh --mode standard --version vX.Y.Z
```

Use `swift package` subcommands for structural package work when they cover the change. Keep manual `Package.swift` edits minimal and intentional when the CLI does not cover the needed configuration.

## Review and Delivery

### Review Expectations

- Use Swift Testing (`import Testing`) as the default test framework. Do not introduce XCTest unless an external constraint requires it.
- When touching normalization or runtime behavior, add or update focused tests in `Tests/TextForSpeechTests` in the same pass.
- Keep formatting and linting choices consistent with the existing repository direction. If formatter or linter config is added or changed, prefer clear maintainable rule intent over style churn.
- Preserve checklist-style structure in `ROADMAP.md`.

### Definition of Done

Work is not done until the relevant code, tests, docs, and maintainer guidance agree with the package behavior that now exists.

For package changes, run `swift build` and `swift test`. For repo-guidance, release, or maintenance-tooling changes, also run `sh scripts/repo-maintenance/validate-all.sh`.

## Safety Boundaries

### Never Do

- Never run multiple SwiftPM or Xcode build or test commands concurrently.
- Never hand-edit `Package.resolved` or other package-manager generated outputs.
- Never introduce machine-local dependency declarations, lockfile entries, scripts, docs, examples, generated project files, or CI config that point at `/Users/...`, `~/...`, `../...`, local worktrees, or private checkout paths.
- Never reintroduce a separate forensic surface unless the package regains a real analysis use case that earns its own API.
- Never leave legacy compatibility shims, stringly typed fallback surfaces, transitional wrappers, or duplicate codepaths behind after cleanup unless Gale explicitly approves that compromise.

### Ask Before

- Ask before changing public API shape, runtime persistence format, built-in profile semantics, or release behavior.
- Ask before widening a narrow normalization fix into an architectural pivot.
- Ask before using `xcodebuild`; prefer SwiftPM unless the task truly depends on Apple SDK or Xcode-managed behavior that SwiftPM alone does not cover.

## Local Overrides

There are no nested `AGENTS.md` files in this repository today. If a deeper guidance file is added later, that closer file refines this root guidance for work inside its subtree.

## Swift Package Workflow

- Use `swift build` and `swift test` as the default first-pass validation commands for this package.
- Use `bootstrap-swift-package` when a new Swift package repo still needs to be created from scratch.
- Use `sync-swift-package-guidance` when the repo guidance for this package drifts and needs to be refreshed or merged forward.
- Re-run `sync-swift-package-guidance` after substantial package-workflow or plugin updates so local guidance stays aligned.
- Use `swift-package-build-run-workflow` for manifest, dependency, plugin, resource, Metal-distribution, build, and run work when `Package.swift` is the source of truth.
- Use `swift-package-testing-workflow` for Swift Testing, XCTest holdouts, `.xctestplan`, fixtures, and package test diagnosis.
- Use `scripts/repo-maintenance/validate-all.sh` for local maintainer validation, `scripts/repo-maintenance/sync-shared.sh` for repo-local sync steps, and `scripts/repo-maintenance/release.sh` for releases.
- Treat `scripts/repo-maintenance/config/profile.env` as the installed `maintain-project-repo` profile marker, and keep it on the `swift-package` profile for plain package repos.
- Read relevant SwiftPM, Swift, and Apple documentation before proposing package-structure, dependency, manifest, concurrency, or architecture changes.
- Prefer Dash or local Swift docs first, then official Swift or Apple docs when local docs are insufficient.
- Prefer the simplest correct Swift that is easiest to read and reason about.
- Prefer synthesized and framework-provided behavior over extra wrappers and boilerplate.
- Keep data flow straight and dependency direction unidirectional.
- Treat `Package.swift` as the source of truth for package structure, targets, products, and dependencies.
- Prefer `swift package` subcommands for structural package edits before manually editing `Package.swift`.
- Edit `Package.swift` intentionally and keep it readable; agents may modify it when package structure, targets, products, or dependencies need to change, and should try to keep package graph updates consolidated in one change when possible.
- Keep `Package.swift` explicit about its package-wide Swift language mode. On current Swift 6-era manifests, prefer `swiftLanguageModes: [.v6]` as the default declaration, treat `swiftLanguageVersions` as a legacy alias used only when an older manifest surface requires it, and remember that lowering the manifest's `// swift-tools-version:` from the bootstrap default is often appropriate when the package should support an older Swift 6 toolchain, but never below `6.0`.
- Avoid adding unnecessary dependency-provenance detail or switching to branch/revision-based requirements unless the user explicitly asks for that level of control.
- Treat `Package.resolved` and similar package-manager outputs as generated files; do not hand-edit them.
- Prefer Swift Testing by default unless an external constraint requires XCTest.
- Use `apple-ui-accessibility-workflow` when the package work crosses into SwiftUI accessibility semantics, Apple UI accessibility review, or UIKit/AppKit accessibility bridge behavior.
- Keep package resources under the owning target tree, declare them intentionally with `Resource.process(...)`, `Resource.copy(...)`, `Resource.embedInCode(...)`, and load them through `Bundle.module`.
- Keep test fixtures as test-target resources instead of relying on the working directory.
- Bundle precompiled Metal artifacts such as `.metallib` files as explicit resources when they ship with the package, and prefer `xcode-build-run-workflow` when shader compilation or Apple-managed Metal toolchain behavior matters.
- Validate both Debug and Release paths when optimization or packaging differences matter, and treat tagged releases as a cue to verify the Release artifact path before publishing.
- Prefer `xcode-build-run-workflow` or `xcode-testing-workflow` only when package work needs Xcode-managed SDK, toolchain, or test behavior.
- Keep runtime UI accessibility verification and XCUITest follow-through in `xcode-testing-workflow` rather than treating package-side testing as a substitute for live UI verification.
