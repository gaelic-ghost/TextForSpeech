# TextForSpeech Public API Audit

## Purpose

This note records the public API simplification audit started on
`audit/public-api-simplification`.

The practical question is:

> "What does a package consumer have to understand before they can normalize
> text, manage custom pronunciation profiles, or configure runtime behavior?"

For this package, the clearest public API should let callers do those jobs
without also learning maintainer-only composition details, persistence repair
internals, or provider implementation mechanics.

## Source of truth used for the audit

`Package.swift` vends one Swift Package Manager library product named
`TextForSpeech`, backed by the `TextForSpeech` target. In SwiftPM terms, that
means public declarations in the target are the client-facing package API.

The audit checked:

- `Package.swift`
- public declarations under `Sources/TextForSpeech`
- README usage examples
- maintainer guidance under `docs/maintainers`
- release notes for recent public API reshapes
- tests that exercise public runtime and normalization behavior
- Swift symbol graph output for public symbols

## Remediated targets

### 1. Built-in profile fragments are not public API

The built-in profile implementation is intentionally split by semantic role:

- semantic aliases
- scalar pronunciations
- extension aliases
- token transforms
- style presets

That split is valuable for maintainers because it keeps future built-in
pronunciation edits local and reviewable. It is not a caller-facing model.

The public surface that callers should see is:

- `TextForSpeech.Profile.semanticCore`
- `TextForSpeech.Profile.builtInStyle(_:)`
- `TextForSpeech.Profile.builtInBase(style:)`
- `TextForSpeech.Profile.base`
- `TextForSpeech.Profile.default`

The internal fragment arrays and preset values stay module-internal:

- `semanticAliasReplacements`
- `scalarPronunciationReplacements`
- `extensionAliasReplacements`
- `semanticTokenTransformReplacements`
- `balancedBuiltInStyle`
- `compactBuiltInStyle`
- `explicitBuiltInStyle`

Practical reason: callers should choose a style or compose a built-in base, not
depend on the package's private inventory of built-in replacement fragments.
Keeping those fragments public would make future built-in cleanup look like a
public API break even when the supported behavior did not change.

### 2. Runtime state mutation goes through grouped handles

The runtime currently exposes grouped handles that describe the intended caller
workflow:

- `runtime.style`
- `runtime.summary`
- `runtime.profiles`
- `runtime.normalize`
- `runtime.persistence`

That shape is good. The selected runtime values remain readable:

- `runtime.builtInStyle`
- `runtime.activeSummaryConfiguration`

Their setters are module-internal, so an external caller cannot change runtime
behavior without going through the operations that persist the change. This
avoids two subtly different ways to change the same state:

- `try runtime.style.setActive(to: .compact)` changes and persists the style.
- direct mutation would change memory only and could be lost.

Practical reason: for a runtime object whose job includes durable profile and
setting ownership, mutation should be hard to perform without the matching save
behavior. External callers can still read the current values through grouped
getters, but state-changing calls should stay centralized.

### 4. Runtime profile details have one identity spelling

`Runtime.Profiles.Details` uses `id` as its one public identity spelling.
Because `Details` conforms to `Identifiable`, `id` carries the identity role
naturally. Keeping a second `profileID` spelling would invite inconsistent call
sites and make examples look more complicated than the model really is.

Practical reason: one profile details value should answer "which profile is
this?" in one way. `summary.id` remains available for the same profile id inside
the nested summary, and `details.id` is the direct identity of the details
record.

### 5. Summary configuration describes the setting, not only the backend

`TextForSpeech.SummaryConfiguration` is now the caller-facing summary setting.
It carries a concrete `SummaryProvider` backend selector today, but the public
normalization and runtime APIs no longer treat the provider enum as the whole
concept:

- `TextForSpeech.Normalize.text(..., summary:summarize:)`
- `TextForSpeech.Normalize.source(..., summary:summarize:)`
- `runtime.summary.get()`
- `runtime.summary.list()`
- `runtime.summary.set(_:)`

Practical reason: callers still choose the concrete backend they need, but the
API now has a stable place to add model selection, fallback policy, local-only
constraints, or privacy controls without reshaping every call site again.

## Deferred design questions

### 3. Should `PersistedState` be public?

`TextForSpeech.PersistedState` exposes the concrete JSON archive shape as a
public value. That can be useful if callers need explicit import/export,
migration tooling, diagnostics, or backup workflows. It is too much if ordinary
callers only need the runtime to save and load itself.

The practical design question is whether the package wants to support
state-file tooling as a real public use case. If yes, `PersistedState` should be
documented as an advanced archive contract. If no, the runtime should hide it
behind narrower persistence operations.

### 6. Does `Replacement` need a simpler authoring surface?

`TextForSpeech.Replacement` intentionally exposes a powerful rule model:

- match kind
- token kind
- line kind
- phase
- transform
- format scopes
- priority

That model is useful for built-ins and advanced callers. It is more machinery
than a common app-level customization needs when the job is just "say this word
or token differently."

The practical design question is whether to add convenience factories or a
small authoring facade for the common custom-profile cases while keeping the
advanced replacement model available.
