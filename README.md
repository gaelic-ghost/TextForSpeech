# TextForSpeech

A Swift package for turning hard-to-speak source text into speech-safe text before it reaches a speech model.

## Overview

`TextForSpeech` owns the text-conditioning layer that `SpeakSwiftly` now consumes as an external package. It preserves the always-on built-in normalization rules that keep the speech model reliable, and it layers optional custom profiles and replacement rules on top of that base behavior.

The package exposes three main pieces:

- `TextForSpeech`
  The namespaced normalization API and model types.
- `TextForSpeechRuntime`
  The observable runtime owner for active and stored text profiles.
- JSON-backed profile persistence through `load()`, `save()`, and `restore(_:)`.

## Usage

### Normalize text directly

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

If you omit `context.format`, `TextForSpeech` will detect a likely format before running the normalization pipeline.

### Manage profiles and replacements

```swift
import TextForSpeech

let runtime = TextForSpeechRuntime()

try runtime.createProfile(id: "logs", named: "Logs")
try runtime.addReplacement(
    TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule"),
    toStoredProfileNamed: "logs"
)

runtime.use(
    TextForSpeech.Profile(
        id: "ops",
        name: "Ops",
        replacements: [
            TextForSpeech.Replacement("stdout", with: "standard output", id: "stdout-rule")
        ]
    )
)

let effectiveProfile = runtime.snapshot(named: "logs")
```

### Persist profile state

```swift
import TextForSpeech

let fileURL = URL(fileURLWithPath: "/tmp/text-profiles.json")
let runtime = TextForSpeechRuntime(persistenceURL: fileURL)

try runtime.createProfile(id: "logs", named: "Logs")
try runtime.save()
try runtime.load()
```

## Model shape

The current package model is intentionally hybrid:

- `TextForSpeech.Profile.base`
  The always-on built-in normalization layer.
- `TextForSpeech.Profile.default`
  The default empty custom profile.
- `TextForSpeechRuntime.customProfile`
  The active editable custom layer for a runtime.
- `TextForSpeechRuntime.profiles`
  Stored named custom layers.

The effective profile for a job is the base profile merged with either the selected stored profile or the active custom profile.

## Development

Use the standard Swift package checks:

```bash
swift build
swift test
```
