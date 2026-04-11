# TextForSpeech

A Swift package for turning code-heavy, path-heavy, and markdown-heavy developer text into speech-safe text before it reaches a speech model.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
- [Usage](#usage)
- [Runtime profiles](#runtime-profiles)
- [Source layout](#source-layout)
- [Development](#development)
- [Verification](#verification)
- [License](#license)

## Overview

`TextForSpeech` owns the text-conditioning layer that `SpeakSwiftly` consumes as an external package. It ships one semantic built-in core plus a selectable built-in `style`, then layers persisted custom profiles on top so callers can tune pronunciation without reimplementing the core normalization pipeline.

The package currently has three main responsibilities:

- normalize mixed text such as markdown, logs, CLI output, and prose with embedded code or identifiers
- normalize whole-source input through an explicit source lane
- persist and edit named custom profiles while keeping the built-in base layer always on

### Motivation

Speech models do poorly with raw developer text such as file paths, identifiers, markdown links, inline code, repeated separators, and repeated-letter runs. `TextForSpeech` centralizes those cleanup rules so the same behavior can be reused across callers instead of being reimplemented in app code or worker code.

## Setup

`TextForSpeech` is a Swift Package Manager library product targeting iOS 17, macOS 14, and Swift 6 language mode.

During local development, add it to another package with a local path dependency:

```swift
dependencies: [
    .package(path: "../TextForSpeech"),
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

Then import `TextForSpeech` in the targets that need normalization or runtime-managed profile state.

## Usage

Normalize mixed text directly when you want the default built-in `.balanced` style and an optional path context:

```swift
import TextForSpeech

let normalized = TextForSpeech.Normalize.text(
    "stderr: /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/WorkerRuntime.swift",
    context: TextForSpeech.Context(
        cwd: "/Users/galew/Workspace/SpeakSwiftly",
        repoRoot: "/Users/galew/Workspace/SpeakSwiftly"
    )
)
```

If you omit `format`, `TextForSpeech` detects a likely outer text format before running the text normalization pipeline.

If you want a different shipped listening mode, pass `style:`:

```swift
import TextForSpeech

let normalized = TextForSpeech.Normalize.source(
    sourceText,
    as: .swift,
    style: .compact
)
```

The shipped styles now differ in concrete coding-agent ways:

- `.compact` assumes more visual context and says less. It drops the broad line-based spoken-code expansion and keeps common shapes terse, such as `foo()` -> `foo`, `#123` -> `123`, and `--help` -> `help`.
- `.balanced` is the default general-purpose mode. It keeps spoken-code expansion for code-like lines and speaks common references more explicitly, such as `foo()` -> `foo function`, `#123` -> `issue 123`, and `WorkerRuntime.swift:42:7` -> `Worker Runtime dot swift line 42 column 7`.
- `.explicit` is the audio-first mode. It keeps the same line-based spoken-code expansion as `.balanced`, but uses more narrated phrasing for common coding-agent shapes, such as `foo()` -> `foo function call`, `#123` -> `issue number 123`, and `--help` -> `long flag help`.

For repeated file paths in the same utterance, the text lane now also compacts repeated anchors before the built-in path-speaking pass. The first path still speaks normally, but later repeated mentions can collapse to shorter phrases such as `same directory, Worker Runtime dot swift` or `same path` instead of repeating the full spoken prefix.

When the outer document is mixed text but the embedded code language is known, pass `nestedFormat` so fenced or inline code can route through the source lane:

```swift
import TextForSpeech

let normalized = TextForSpeech.Normalize.text(
    """
    Read this first:

    ```swift
    let sampleRate = profile?.sampleRate ?? 24000
    ```
    """,
    format: .markdown,
    nestedFormat: .swift
)
```

Use the source lane when the whole input is a source file or editor buffer and the caller already knows the language:

```swift
import TextForSpeech

let normalized = TextForSpeech.Normalize.source(
    """
    struct WorkerRuntime {
        let sampleRate: Int
    }
    """,
    as: .swift
)
```

The source lane is explicit today but still generic. It normalizes whole-source input more consistently than the mixed-text lane, but SwiftSyntax-backed Swift-specific structure is still future roadmap work rather than current behavior.

The package also exposes one small lexical helper when a caller needs natural-language word tokenization:

```swift
import TextForSpeech

let words = TextForSpeech.Forensics.words(
    in: "Please read /tmp/Thing and NSApplication.didFinishLaunchingNotification."
)
```

## Runtime Profiles

Use `TextForSpeech.Runtime` when you need an observable owner for stored custom profiles, one active custom profile id, one selected built-in style, and default-on JSON-backed persistence in Application Support:

```swift
import TextForSpeech

let runtime = try TextForSpeech.Runtime(builtInStyle: .balanced)

try runtime.profiles.setBuiltInStyle(.compact)
try runtime.profiles.create(id: "logs", name: "Logs")
try runtime.profiles.add(
    TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule"),
    toProfileID: "logs"
)
try runtime.profiles.activate(id: "logs")

let normalized = TextForSpeech.Normalize.text(
    "stderr and stdout",
    customProfile: runtime.profiles.active(),
    style: runtime.profiles.builtInStyle
)
```

The runtime model is intentionally explicit:

- `TextForSpeech.Profile.semanticCore` is the always-on semantic built-in layer.
- `TextForSpeech.Profile.builtInStyle(_:)` returns one shipped style preset.
- `TextForSpeech.Profile.builtInBase(style:)` composes `semanticCore + style preset`.
- `TextForSpeech.Profile.base` is the default `.balanced` built-in base for convenience.
- `TextForSpeech.Profile.default` is the empty default custom profile value.
- `runtime.profiles.builtInStyle` is the currently selected shipped style preset.
- `runtime.profiles.activeID` is the stored custom profile id currently selected by the runtime.
- `runtime.profiles.active()` is the raw active custom profile.
- `runtime.profiles.effective()` is always `builtInBase(style: builtInStyle) + active custom`.
- `runtime.profiles.stored(id:)` reads a named stored custom profile without activating it.

Persistence is default-on. `TextForSpeech.Runtime()` writes to Application Support automatically, namespaced by the host bundle identifier when one is available and falling back to `TextForSpeech` when it is not. The selected built-in style is persisted alongside the active custom profile id and stored custom profiles.

## Source Layout

The package source lives under `Sources/TextForSpeech` and is organized by responsibility:

- `API/`
  Public namespace-first entrypoints such as `Normalize` and `Forensics`.
- `Models/`
  Core value types such as `Profile`, `Replacement`, `Context`, and the built-in profiles.
- `Normalization/`
  The text lane, source lane, structural markdown parsing, replacement-rule engine, speech helpers, and format detection.
- `Runtime/`
  Runtime ownership, grouped profile and persistence handles, persisted state, and runtime-facing errors.
The current source split keeps structural normalization logic separate from durable lexical policy:

- structural work such as markdown parsing, code-span extraction, and format detection stays in code
- durable lexical policy such as built-in aliases, identifier speaking, path speaking, URL speaking, repeated-letter-run handling, and style-specific speaking policy lives in the built-in profile layers

Tests live under `Tests/TextForSpeechTests` and are grouped by role:

- `Models/`
- `Normalization/`
- `Runtime/`
- top-level lexical helper coverage

## Development

Use the standard Swift package workflow from the repository root:

```bash
swift build
swift test
```

## Verification

The baseline verification path for this repository is:

```bash
swift build
swift test
```

For release work or architectural refactors, also review the current roadmap in [ROADMAP.md](ROADMAP.md) and the maintainer notes under [docs/maintainers](docs/maintainers).

## License

This project is licensed under the Apache License 2.0. See [LICENSE](LICENSE) for the full text.
