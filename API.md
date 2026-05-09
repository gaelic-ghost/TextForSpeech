# TextForSpeech API Reference

Use this reference to understand the public Swift normalization API, runtime profile API, request and response models, and local verification path for TextForSpeech.

## Table of Contents

- [Overview](#overview)
- [API Surface](#api-surface)
- [Authentication and Access](#authentication-and-access)
- [Requests and Responses](#requests-and-responses)
- [Errors](#errors)
- [Versioning and Compatibility](#versioning-and-compatibility)
- [Local Development and Verification](#local-development-and-verification)
- [Support and Ownership](#support-and-ownership)

## Overview

### Who This API Is For

This API is for Swift packages, apps, local services, and tools that need to turn developer-heavy text into speech-safe text before handing it to a speech model.

The package serves two consumer shapes:

- stateless callers that use `TextForSpeech.Normalize`
- stateful callers that use `TextForSpeech.Runtime` to persist built-in style, active custom profile, stored profiles, replacements, and summarization provider settings

### Stability Status

The namespace-first normalization surface centered on `TextForSpeech.Normalize` and `TextForSpeech.Runtime` is the supported public API for this checkout.

Compatibility shims and separate forensic surfaces are intentionally not part of the current package contract. When behavior or model shape changes, the README, release notes, and tests should move with the public API.

## API Surface

### Entry Points

Stateless normalization entry points:

- `TextForSpeech.Normalize.text(_:requestContext:customProfile:style:summarizationProvider:summarize:)`
- `TextForSpeech.Normalize.source(_:as:requestContext:customProfile:style:summarizationProvider:summarize:)`
- `TextForSpeech.Normalize.detectTextFormat(in:)`

Stateful runtime entry points:

- `TextForSpeech.Runtime.init(builtInStyle:persistence:fileManager:bundle:)`
- `runtime.normalize.text(...)`
- `runtime.normalize.source(...)`
- `runtime.profiles`
- `runtime.style`
- `runtime.summarizationProvider`
- `runtime.persistence`

Core model entry points:

- `TextForSpeech.Profile`
- `TextForSpeech.Replacement`
- `TextForSpeech.RequestContext`
- `TextForSpeech.BuiltInProfileStyle`
- `TextForSpeech.TextFormat`
- `TextForSpeech.SourceFormat`
- `TextForSpeech.PersistedState`

### Protocols and Transports

TextForSpeech is an in-process Swift package. Callers import `TextForSpeech` and call asynchronous normalization methods or synchronous runtime profile operations directly.

There is no HTTP, MCP, CLI, or daemon protocol in this package. Server and plugin transports are owned by downstream consumers such as SpeakSwiftly and SpeakSwiftlyServer.

## Authentication and Access

### Credentials

The package has no token, secret, certificate, or user-session requirement. Access is local to the Swift process that imports the package.

### Permissions

Stateless normalization does not need filesystem access. Runtime persistence needs normal read and write access to the configured persistence file. The default runtime persistence path is derived from Application Support for the calling bundle.

Summarization is optional. When `summarize: true` is passed, the selected `TextForSpeech.SummarizationProvider` determines whether the calling process needs additional platform capability or model availability.

## Requests and Responses

### Request Shape

`Normalize.text` accepts mixed prose, markdown, logs, CLI output, paths, identifiers, and code-heavy text. Optional inputs include:

- `requestContext`, which can carry source, topic, current directory, repository root, and arbitrary string attributes
- `customProfile`, a `TextForSpeech.Profile` merged with the built-in base profile
- `style`, one of the built-in normalization styles
- `summarizationProvider`
- `summarize`

`Normalize.source` accepts whole-source input plus a required `TextForSpeech.SourceFormat`. It uses the same optional request-context, custom-profile, style, summarization-provider, and summarize inputs.

Runtime profile mutations accept profile names, profile IDs, and `TextForSpeech.Replacement` values. Replacements can match exact phrases, whole tokens, token kinds, or line kinds, and can apply literal output or built-in speech transforms.

### Response Shape

Normalization calls return a `String` ready for speech. If `RequestContext.source` or `RequestContext.topic` is present, the returned speech text includes a short request-context preface.

Runtime profile queries return profile summaries, profile details, style options, summarization-provider options, persisted state, or the selected built-in style depending on the handle used.

Runtime profile mutations return updated profile details when the changed profile needs to be inspected immediately, or complete without a return value for state changes such as active-profile selection, deletion, reset, load, save, and factory reset.

### Data Models

Important data models include:

- `RequestContext`: source, topic, cwd, repoRoot, and attributes for provenance and path compaction
- `BuiltInProfileStyle`: `.compact`, `.balanced`, and `.explicit`
- `Profile`: profile ID, display name, and ordered replacements
- `Replacement`: match rule, transform, phase, format filters, case-sensitivity, and priority
- `TextFormat`: detected outer text categories for mixed input
- `SourceFormat`: caller-provided source-language categories for whole-source input
- `PersistedState`: versioned runtime profile, style, provider, and active-profile state
- runtime handle models: `Profiles.Summary`, `Profiles.Details`, `Style.Option`, and `SummarizationProviderSettings.Option`

## Errors

### Error Shape

Stateless normalization methods are `async throws` because optional summarization can throw. Runtime initialization and persistence operations throw Swift errors when stored state cannot be loaded, repaired, decoded, encoded, or written.

Profile and replacement operations throw `TextForSpeech.RuntimeError` for actionable state failures such as missing profiles, duplicate profiles, or missing replacements.

### Common Failure Modes

- A profile ID is not found: inspect `runtime.profiles.list()` or the persisted state before setting active profile, editing replacements, or normalizing with a stored profile.
- A profile already exists: choose a different name or rename the existing profile before creating another profile with the same normalized ID.
- A replacement ID is not found: inspect the active or stored profile details before patching or removing a replacement.
- Persisted state cannot be decoded or repaired: check the configured persistence file and whether the persisted state version matches the current package.
- Summarization fails: retry with `summarize: false` or inspect the selected summarization provider.

## Versioning and Compatibility

### Supported Versions

This checkout builds as Swift language mode 6 with Swift tools version 6.2. The package declares macOS 14 and iOS 17 platform floors.

The current manifest depends on `swift-markdown` from `0.7.3` and `SwiftSoup` from `2.13.4`.

### Breaking Changes

Breaking API, persistence, built-in profile, replacement, or normalization behavior changes should be documented in the release notes and reflected in README usage examples.

The package does not keep unsupported compatibility shims after cleanup unless Gale explicitly approves that compromise for a concrete downstream consumer.

## Local Development and Verification

### Runtime Configuration

`TextForSpeech.Runtime` accepts a built-in style and a persistence configuration:

- `.default` uses the platform Application Support default for the calling bundle.
- `.file(URL)` uses an explicit persistence file.

The runtime starts with the `.foundationModels` summarization provider and repairs profile state on initialization.

### Verification

Use SwiftPM validation from the repository root:

```bash
swift build
swift test
```

Use the repo-maintenance gate when API documentation, maintainer guidance, release tooling, or repository workflow files change:

```bash
sh scripts/repo-maintenance/validate-all.sh
```

## Support and Ownership

Gale owns this package under `gaelic-ghost/TextForSpeech`. Use the repository issue tracker and the repo-local maintainer guidance in `AGENTS.md`, `README.md`, `ROADMAP.md`, and `docs/maintainers/` when the API contract is unclear or broken.
