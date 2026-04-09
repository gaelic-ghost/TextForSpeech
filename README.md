# TextForSpeech

A Swift package for turning code-heavy or path-heavy source text into speech-safe text before it reaches a speech model.

## Table of Contents

- [Overview](#overview)
- [Setup](#setup)
- [Usage](#usage)
- [API Notes](#api-notes)
- [Development](#development)
- [Verification](#verification)
- [License](#license)

## Overview

`TextForSpeech` owns the text-conditioning layer that `SpeakSwiftly` consumes as an external package. It keeps the always-on built-in normalization passes in one reusable package, then layers optional profile-driven replacements and runtime persistence on top so callers can tune pronunciation without reimplementing the core pipeline.

### Motivation

Speech models do poorly with raw developer text such as file paths, identifiers, markdown, inline code, repeated punctuation, and repeated-letter runs. This package centralizes those cleanup rules so the same speech-safe behavior can be reused across callers, while still leaving room for custom replacement profiles and lightweight forensic inspection of how the original text was segmented.

## Setup

`TextForSpeech` is a Swift Package Manager library product that currently targets iOS 17, macOS 14, and Swift 6 language mode.

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

After adding the dependency, import `TextForSpeech` in the targets that need normalization or runtime profile management.

## Usage

Normalize mixed text directly when you just need the text lane with the merged built-in behavior and an optional context:

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

Right now the source lane is explicit but still generic. It normalizes whole-source input more consistently than the mixed-text lane, but SwiftSyntax-backed Swift-specific structure is still planned future work rather than current behavior.

Use `TextForSpeech.Runtime` when you need an observable owner for editable custom profiles, stored profiles, and JSON-backed persistence:

```swift
import Foundation
import TextForSpeech

let fileURL = URL(fileURLWithPath: "/tmp/text-profiles.json")
let runtime = TextForSpeech.Runtime(persistenceURL: fileURL)

try runtime.profiles.create(id: "logs", name: "Logs")
try runtime.profiles.add(
    TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule"),
    toStoredProfileID: "logs"
)

let normalized = TextForSpeech.Normalize.text(
    "stderr and stdout",
    profile: runtime.profiles.effective(id: "logs") ?? .default
)

try runtime.persistence.save()
```

The package also exposes forensic helpers when a caller needs to inspect how an input was shaped or segmented:

```swift
import TextForSpeech

let original = """
# Intro
Please read /tmp/Thing and NSApplication.didFinishLaunchingNotification.
"""

let normalized = TextForSpeech.Normalize.text(original)
let features = TextForSpeech.Forensics.features(
    originalText: original,
    normalizedText: normalized
)
let sections = TextForSpeech.Forensics.sections(originalText: original)
```

## API Notes

`TextForSpeech` currently exposes one library product with a small public surface:

- `TextForSpeech.Normalize.text(_:context:profile:format:nestedFormat:)` handles prose, markdown, logs, lists, HTML, and other mixed-document inputs.
- `TextForSpeech.Normalize.source(_:as:context:profile:)` is the explicit whole-source lane for callers that already know the source language.
- `TextForSpeech.Normalize.detectTextFormat(in:)` identifies likely outer text formats such as markdown, log, CLI output, or list-like text.
- `TextForSpeech.Forensics.features(originalText:normalizedText:)`, `sections(originalText:)`, and `sectionWindows(originalText:totalDurationMS:totalChunkCount:)` support post-normalization inspection and chunk planning.
- `TextForSpeech.Runtime` exposes grouped `profiles` and `persistence` capabilities instead of one flat mutation surface.

The current profile model is intentionally hybrid:

- `TextForSpeech.Profile.default` is the empty custom profile.
- `TextForSpeech.Runtime.profiles.active()` reads the active editable custom layer, or a stored layer when passed an `id`.
- `TextForSpeech.Runtime.profiles.effective(id:)` reads the built-in merged profile view used for normalization.
- `TextForSpeech.Runtime.profiles` manages stored custom layers keyed by profile `id`.

The built-in normalization layer is internal and always applied. A normalization job merges that built-in layer with either the active custom profile or the caller-supplied custom profile.

The current roadmap keeps the text/source split in place and tracks structured Swift normalization as a distinct next milestone in [ROADMAP.md](ROADMAP.md).

## Development

Use the standard Swift package workflow from the repository root:

```bash
swift build
swift test
```

The package source lives under [`Sources/TextForSpeech`](Sources/TextForSpeech), and the current test coverage lives under [`Tests/TextForSpeechTests`](Tests/TextForSpeechTests).

## Verification

The baseline verification path for this repository is:

```bash
swift build
swift test
```

The test suite covers end-to-end normalization behavior, runtime profile management, markdown and URL handling, and the current forensic APIs.

## License

This project is licensed under the Apache License 2.0. See [`LICENSE`](LICENSE) for the full text.
