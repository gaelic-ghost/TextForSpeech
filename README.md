# TextForSpeech

A Swift package for turning code-heavy, path-heavy, and markdown-heavy developer text into speech-safe text before it reaches a speech model.

## Table of Contents

- [Overview](#overview)
- [Quick Start](#quick-start)
- [Usage](#usage)
- [Development](#development)
- [Repo Structure](#repo-structure)
- [Release Notes](#release-notes)
- [License](#license)

## Overview

### Status

`TextForSpeech` is actively available as the shared normalization package used by `SpeakSwiftly`.

### What This Project Is

`TextForSpeech` owns the text-conditioning step that prepares developer-heavy text before speech generation. It ships one semantic built-in core plus selectable built-in styles, then layers persisted custom profiles on top so callers can tune pronunciation without reimplementing the core normalization behavior.

The package currently has three main responsibilities:

- normalize mixed text such as markdown, logs, CLI output, and prose with embedded code or identifiers
- normalize whole-source input through an explicit source lane
- persist and edit named custom profiles while keeping the built-in base layer always on

### Motivation

Speech models do poorly with raw developer text such as file paths, identifiers, markdown links, inline code, repeated separators, repeated-letter runs, currency and measurement forms like `$9.39` or `42 km`, and terse scalar or math-heavy tokens like `f32`, `cosF32`, or `WorkerRuntime.swift:42`. `TextForSpeech` centralizes those cleanup rules so the same behavior can be reused across callers instead of being reimplemented in app code or worker code.

## Quick Start

Add `TextForSpeech` as a Swift Package Manager dependency, import `TextForSpeech`, then call the namespace-first normalization API:

```swift
import TextForSpeech

let normalized = try await TextForSpeech.Normalize.text("stderr: WorkerRuntime.swift:42")
```

Add the package from its GitHub repository:

```swift
dependencies: [
    .package(url: "https://github.com/gaelic-ghost/TextForSpeech.git", from: "0.18.9"),
],
targets: [
    .executableTarget(
        name: "ExampleApp",
        dependencies: [
            .product(name: "TextForSpeech", package: "TextForSpeech"),
        ]
    ),
]
```

## Usage

Normalize mixed text directly when you want the default built-in `.balanced` style, optional input context, and optional request metadata:

```swift
import TextForSpeech

let normalized = try await TextForSpeech.Normalize.text(
    "stderr: /workspace/SpeakSwiftly/Sources/SpeakSwiftly/WorkerRuntime.swift",
    withContext: TextForSpeech.InputContext(
        cwd: "/workspace/SpeakSwiftly",
        repoRoot: "/workspace/SpeakSwiftly"
    ),
    requestContext: TextForSpeech.RequestContext(
        source: "codex",
        app: "SpeakSwiftly",
        project: "TextForSpeech"
    )
)
```

If `InputContext.textFormat` is omitted, `TextForSpeech` detects a likely outer text format before running the text normalization path.

If you want a different shipped listening mode, pass `style:`:

```swift
import TextForSpeech

let normalized = try await TextForSpeech.Normalize.source(
    sourceText,
    as: .swift,
    style: .compact
)
```

The shipped styles differ in concrete coding-agent ways:

- `.compact` assumes more visual context and says less. It drops the broad line-based spoken-code expansion, keeps common shapes terse, and keeps `::` silent, such as `foo()` -> `foo`, `#123` -> `123`, and `--help` -> `help`.
- `.balanced` is the default general-purpose mode. It keeps spoken-code expansion for code-like lines, keeps `::` silent, and speaks common references more explicitly, such as `foo()` -> `foo function`, `#123` -> `issue 123`, `--help` -> `double tack help`, `WorkerRuntime.swift:42` -> `Worker Runtime dot swift at line 42`, and `WorkerRuntime.swift:42:7` -> `Worker Runtime dot swift line 42 column 7`.
- `.explicit` is the audio-first mode. It keeps the same line-based spoken-code expansion as `.balanced`, but uses more narrated phrasing for common coding-agent shapes and says `::` as `double colon`, such as `foo()` -> `foo function call`, `#123` -> `issue number 123`, and `--help` -> `long flag help`.

The built-in speech layer also expands common numeric scalar shorthands, currency amounts, and measurement suffixes, so tokens such as `f32` become `float thirty two`, `$9.39` becomes `nine dollars and thirty-nine cents`, `42 km` becomes `forty-two kilometers`, `64Gbps` becomes `sixty four gigabits per second`, and combinations such as `cosF32` become `cosine float thirty two`.

The semantic core also ships extension aliases for especially speech-hostile file types. That includes Xcode-heavy forms such as `.xcodeproj`, `.pbxproj`, `.xcworkspace`, `.xcconfig`, `.xcscheme`, `.xctestplan`, `.xcresult`, `.xcassets`, `.xcstrings`, `.xcprivacy`, and `.dSYM`, plus mixed-stack formats such as `.mdx`, `.tsx`, `.jsx`, `.jsonc`, `.ipynb`, `.wasm`, `.sqlite`, and `.db`.

For repeated file paths in the same utterance, the text path compacts repeated anchors before the built-in path-speaking pass. File-path separators collapse to spacing rather than spoken words, and later repeated mentions can collapse to shorter phrases such as `same directory, Worker Runtime dot swift` or `same path` instead of repeating the full spoken prefix.

When the outer document is mixed text but the embedded code language is known, pass `InputContext.nestedSourceFormat` so fenced or inline code can route through the source path:

```swift
import TextForSpeech

let normalized = try await TextForSpeech.Normalize.text(
    """
    Read this first:

    ```swift
    let sampleRate = profile?.sampleRate ?? 24000
    ```
    """,
    withContext: TextForSpeech.InputContext(
        textFormat: .markdown,
        nestedSourceFormat: .swift
    )
)
```

Use the source path when the whole input is a source file or editor buffer and the caller already knows the language:

```swift
import TextForSpeech

let normalized = try await TextForSpeech.Normalize.source(
    """
    struct WorkerRuntime {
        let sampleRate: Int
    }
    """,
    as: .swift
)
```

The source path is explicit today but still generic. It normalizes whole-source input more consistently than the mixed-text path, but SwiftSyntax-backed Swift-specific structure is still future roadmap work rather than current behavior.

### Summary-Aware Requests

Normalization is deterministic by default. The normalization entrypoints are async so the same ergonomic call can stay local with `summarize: false` or opt into a model summary with `summarize: true`:

```swift
import TextForSpeech

let normalized = try await TextForSpeech.Normalize.text(
    longDeveloperUpdate,
    withContext: TextForSpeech.InputContext(textFormat: .markdown),
    summarizationProvider: .openAIResponses,
    summarize: true
)
```

The summarization provider is explicit because each backend option has a different operating surface:

- `.openAIResponses` calls the OpenAI Responses API and reads `OPENAI_API_KEY` from the process environment.
- `.codexExec` runs the local Codex CLI through `codex exec`.
- `.foundationModels` uses Apple's on-device Foundation Models framework when the framework and operating system support it.

The `summarize` argument defaults to `false`, so deterministic callers do not need a separate convenience method. `TextForSpeech.SummarizationProvider` selects the backend used when `summarize` is `true`.

### Runtime Profiles

Use `TextForSpeech.Runtime` when you need an observable owner for stored custom profiles, one active custom profile id, one selected built-in style, one selected summarization provider, and JSON-backed persistence configured through a small enum:

```swift
import TextForSpeech

let runtime = try TextForSpeech.Runtime(
    builtInStyle: .balanced,
    persistence: .default
)

try runtime.style.setActive(to: .compact)
let logs = try runtime.profiles.create(name: "Logs")
try runtime.profiles.addReplacement(
    TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule"),
    toProfile: logs.id
)
try runtime.profiles.setActive(id: logs.id)

let normalized = try await runtime.normalize.text("stderr and stdout")

try runtime.summarizationProvider.set(.openAIResponses)
let summarized = try await runtime.normalize.text(
    longDeveloperUpdate,
    summarize: true
)
```

The runtime model is intentionally explicit:

- `TextForSpeech.Profile.semanticCore` is the always-on semantic built-in layer.
- `TextForSpeech.Profile.builtInStyle(_:)` returns one shipped style preset.
- `TextForSpeech.Profile.builtInBase(style:)` composes `semanticCore + style preset`.
- `TextForSpeech.Profile.base` is the default `.balanced` built-in base for convenience.
- `TextForSpeech.Profile.default` is the empty default custom profile value.
- `runtime.style.getActive()` returns the currently selected shipped style preset.
- `runtime.style.list()` returns the available built-in style presets with short summaries.
- `runtime.summarizationProvider.get()` returns the provider used by async summary-aware normalization requests.
- `runtime.summarizationProvider.list()` returns the available summarization providers with short summaries.
- `runtime.summarizationProvider.set(_:)` persists the selected summarization provider.
- `runtime.profiles.getActive()` returns the active custom profile's id, a summary, and its replacements.
- `runtime.profiles.getEffective()` returns the active custom profile as merged with the currently selected built-in style.
- `runtime.profiles.get(id:)` reads one stored custom profile summary and its replacements by id.
- `runtime.profiles.create(name:)` creates one stored custom profile and returns its generated id to the caller.
- `runtime.normalize.text(...)` and `runtime.normalize.source(...)` apply `builtInBase(style: style.getActive()) + active custom` without exposing the merged profile value. `summarize` defaults to `false`.
- `try await runtime.normalize.text(..., summarize: true)` and `try await runtime.normalize.source(..., summarize: true)` use the active summarization provider before returning normalized speech-safe text.

Persistence defaults to `.default`. `TextForSpeech.Runtime()` writes to Application Support automatically, namespaced by the host bundle identifier when one is available and falling back to `TextForSpeech` when it is not. In debug builds for bundled targets, the default store uses `TextForSpeech-Debug` instead so local debug runs do not touch the production namespace. Callers that need an explicit location can pass `.file(url)`. The selected built-in style and selected summarization provider are persisted alongside the active custom profile id and stored custom profiles.

## Development

### Setup

`TextForSpeech` is a Swift Package Manager library product targeting iOS 17, macOS 14, and Swift 6 language mode.

No generated project setup is required for ordinary local development. Work from the repository root with SwiftPM.

### Workflow

Use the standard Swift package workflow for code and tests:

```bash
swift build
swift test
```

The repository also uses repo-owned maintainer scripts for validation, shared sync work, and releases:

```bash
sh scripts/repo-maintenance/validate-all.sh
sh scripts/repo-maintenance/sync-shared.sh
sh scripts/repo-maintenance/release.sh --mode standard --version vX.Y.Z
```

For repository workflow expectations, architecture boundaries, and doc-sync rules, see [CONTRIBUTING.md](CONTRIBUTING.md), [ROADMAP.md](ROADMAP.md), and the maintainer notes under [docs/maintainers](docs/maintainers).

### Validation

The baseline verification path for this repository is:

```bash
swift build
swift test
sh scripts/repo-maintenance/validate-all.sh
```

The repository also includes checked-in SwiftFormat and SwiftLint configuration:

```bash
swiftformat --lint --config .swiftformat .
swiftlint lint --config .swiftlint.yml
```

Run those formatter and lint commands when style-tooling changes are in scope or when a change touches enough Swift code that a formatting pass is useful.

## Repo Structure

```text
.
├── Package.swift
├── Sources/TextForSpeech/
│   ├── API/
│   ├── Models/
│   ├── Normalization/
│   └── Runtime/
├── Tests/TextForSpeechTests/
│   ├── Models/
│   ├── Normalization/
│   └── Runtime/
├── docs/
│   ├── maintainers/
│   └── releases/
└── scripts/repo-maintenance/
```

`Sources/TextForSpeech` is organized by responsibility:

- `API/` contains public namespace-first entrypoints such as `Normalize`.
- `Models/` contains core value types such as `Profile`, `Replacement`, `InputContext`, and `SummarizationProvider`, plus the built-in profile composition surface and semantic-role fragments under `Models/BuiltInProfiles/`.
- `Normalization/` contains the text path, source path, structural markdown parsing, replacement-rule engine, speech helpers, format detection, and summary execution support.
- `Runtime/` contains runtime ownership, grouped profile, style, summary, and persistence handles, persisted state, and runtime-facing errors.

The current source split keeps structural normalization logic separate from durable lexical policy:

- structural work such as markdown parsing, code-span extraction, and format detection stays in code
- durable lexical policy such as built-in aliases, extension aliases, identifier speaking, path speaking, URL speaking, repeated-letter-run handling, and style-specific speaking policy lives in the built-in profile layers

Tests live under `Tests/TextForSpeechTests` and are grouped by role, with focused normalization files for path and identifier behavior, markdown and URL behavior, and broader end-to-end flows.

## Release Notes

Release notes live under [docs/releases](docs/releases). Each release note should stay factual, scoped to the tagged change, and explicit about behavior or API shifts.

Use the repo-owned release command for standard release work:

```bash
sh scripts/repo-maintenance/release.sh --mode standard --version vX.Y.Z
```

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for the full text.
