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

`TextForSpeech` is a Swift Package Manager library product that currently targets macOS 15 and Swift 6 language mode.

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

Normalize raw text directly when you just need the merged built-in behavior and an optional context:

```swift
import TextForSpeech

let normalized = TextForSpeech.normalize(
    "stderr: /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/WorkerRuntime.swift",
    context: TextForSpeech.Context(
        cwd: "/Users/galew/Workspace/SpeakSwiftly",
        repoRoot: "/Users/galew/Workspace/SpeakSwiftly"
    )
)
```

If you omit `context.format`, the package detects a likely input format before running the normalization pipeline.

Use `TextForSpeechRuntime` when you need an observable owner for editable custom profiles, stored profiles, and JSON-backed persistence:

```swift
import Foundation
import TextForSpeech

let fileURL = URL(fileURLWithPath: "/tmp/text-profiles.json")
let runtime = TextForSpeechRuntime(persistenceURL: fileURL)

try runtime.createProfile(id: "logs", named: "Logs")
try runtime.addReplacement(
    TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule"),
    toStoredProfileNamed: "logs"
)

let normalized = TextForSpeech.normalize(
    "stderr and stdout",
    profile: runtime.snapshot(named: "logs")
)

try runtime.save()
```

The package also exposes forensic helpers when a caller needs to inspect how an input was shaped or segmented:

```swift
import TextForSpeech

let original = """
# Intro
Please read /tmp/Thing and NSApplication.didFinishLaunchingNotification.
"""

let normalized = TextForSpeech.normalize(original)
let features = TextForSpeech.forensicFeatures(
    originalText: original,
    normalizedText: normalized
)
let sections = TextForSpeech.sections(originalText: original)
```

## API Notes

`TextForSpeech` currently exposes one library product with a small public surface:

- `TextForSpeech.normalize(_:context:profile:as:)` runs the built-in normalization pipeline merged with the provided custom profile.
- `TextForSpeech.detectFormat(in:)` identifies likely input formats such as markdown, Swift, or list-like text.
- `TextForSpeech.forensicFeatures(originalText:normalizedText:)`, `sections(originalText:)`, and `sectionWindows(originalText:totalDurationMS:totalChunkCount:)` support post-normalization inspection and chunk planning.
- `TextForSpeechRuntime` owns `baseProfile`, `customProfile`, stored named profiles, and JSON-backed `load()`, `save()`, and `restore(_:)`.

The current profile model is intentionally hybrid:

- `TextForSpeech.Profile.base` is the always-on built-in normalization layer.
- `TextForSpeech.Profile.default` is the empty custom profile.
- `TextForSpeechRuntime.customProfile` is the active editable custom layer.
- `TextForSpeechRuntime.profiles` stores named custom layers.

The effective profile for a normalization job is the base profile merged with either the selected stored profile or the active custom profile.

## Development

Use the standard Swift package workflow from the repository root:

```bash
swift build
swift test
```

The package source lives under [`Sources/TextForSpeech`](/Users/galew/Workspace/TextForSpeech/Sources/TextForSpeech), and the current test coverage lives under [`Tests/TextForSpeechTests`](/Users/galew/Workspace/TextForSpeech/Tests/TextForSpeechTests).

## Verification

The baseline verification path for this repository is:

```bash
swift build
swift test
```

The test suite covers end-to-end normalization behavior, runtime profile management, markdown and URL handling, and the current forensic APIs.

## License

This repository does not currently include a committed `LICENSE` file. Until one is added, treat the code as unlicensed source rather than assuming an open-source grant.
