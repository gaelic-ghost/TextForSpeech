# TextForSpeech Profiles, Replacements, and Slices

## Why this exists

This note explains the current `TextForSpeech` model in maintainer terms, with special attention to three ideas that are easy to conflate:

- normalization profiles
- text replacements
- slices

The first two are first-class public API. The third is still only partially formalized, but the public package already exposes section and section-window forensic data that behaves like the first draft of a slice system.

## Normalization profile

A normalization profile is the reusable custom rule set that rides on top of the always-on base normalizer.

Today that type is `TextForSpeech.Profile`. It stays intentionally small:

- `id`
- `name`
- `replacements`

The important design choice is that a profile is not the whole normalization engine. It does not carry request-local path context, detected format, or runtime-owned persistence state. It answers a narrower question:

> "What custom rewrite rules should run around the built-in speech-safe normalizer?"

That keeps the responsibilities clean:

- `TextForSpeech.Context` carries request-local environment like `cwd`, `repoRoot`, and optional format hints.
- `TextForSpeech.Profile` carries the reusable custom replacement policy.
- `TextForSpeech.Runtime` exposes grouped profile and persistence capabilities.
- the built-in normalizer remains always on through the base profile and the concrete normalization passes.

## Text replacements

Text replacements are the custom rules inside a profile.

Today that type is `TextForSpeech.Replacement`. Each replacement describes:

- what text to match
- what spoken text to substitute
- how to match it
- when to run it
- which formats it applies to
- how strongly it should win against other rules

The simplest way to think about a replacement is:

> "If this source text shows up in this kind of input, rewrite it to this more speakable form at this point in the pipeline."

## Replacement phases

The phase split is still the part that matters most architecturally.

`beforeBuiltIns` means:

- run this rule before the built-in normalizer rewrites paths, identifiers, links, and code-ish text
- use this when you need to protect or rename hard-to-speak source text before the built-ins touch it

`afterBuiltIns` means:

- run this rule after the built-in normalizer has already made the text more speakable
- use this when you want final-pass polish on the spoken output

## Input formats

Formats are now split by lane.

For mixed text and container documents, use `TextForSpeech.TextFormat`, with cases such as:

- `plain`
- `markdown`
- `html`
- `log`
- `cli`
- `list`

For whole-file or whole-buffer source normalization, use `TextForSpeech.SourceFormat`, with cases such as:

- `generic`
- `swift`
- `python`
- `rust`

The important behavior is that source formats still match hierarchically. `SourceFormat.generic` is the broad bucket that can stand in for any source lane.

`TextForSpeech.Context` can now carry:

- `textFormat`
- `nestedSourceFormat`

Callers can provide those when they know better, but the package can still detect a likely outer text format for the text lane when it is omitted.

## Runtime ownership

The runtime-owned profile holder is `TextForSpeech.Runtime`.

It now exposes:

- `profiles`
- `persistence`
- `persistenceURL`

The core runtime operations are:

- `profiles.active(id:)`
- `profiles.effective(id:)`
- `profiles.stored(id:)`
- `profiles.list()`
- `profiles.use(_:)`
- `profiles.store(_:)`
- `profiles.create(id:name:replacements:)`
- `profiles.delete(id:)`
- `profiles.add(_:)`
- `profiles.add(_:toStoredProfileID:)`
- `profiles.replace(_:)`
- `profiles.replace(_:inStoredProfileID:)`
- `profiles.removeReplacement(id:)`
- `profiles.removeReplacement(id:fromStoredProfileID:)`
- `persistence.state`
- `persistence.load()`
- `persistence.save()`
- `persistence.restore(_:)`

The concurrency model is still snapshot-per-job:

- profile edits can change the active state immediately
- already-started jobs keep the snapshot they began with
- later jobs see the updated effective profile

## How profiles and replacements are added today

Profiles can still be built as plain value types, but the runtime editing workflow is now first-class.

Value-style setup still works:

1. build a `TextForSpeech.Profile`
2. put `TextForSpeech.Replacement` values into its `replacements` array
3. hand that profile to `TextForSpeech.Runtime` through `profiles.use(_:)` or `profiles.store(_:)`

The runtime-owned editing path is now available too:

- `profiles.create(id:name:replacements:)`
- `profiles.add(_:)`
- `profiles.add(_:toStoredProfileID:)`
- `profiles.replace(_:)`
- `profiles.replace(_:inStoredProfileID:)`
- `profiles.removeReplacement(id:)`
- `profiles.removeReplacement(id:fromStoredProfileID:)`

That means callers no longer have to rebuild whole profile values for every small persisted edit.

## Default profile behavior

There are now two profile concepts that matter publicly:

- `TextForSpeech.Profile.default`
  The default empty custom profile.
- `TextForSpeech.Runtime.profiles.active()`
  The currently active custom profile for a runtime.

The effective profile for a job is the internal built-in normalization layer merged with either the selected stored profile or the active custom profile.

## Persistence

Yes, `TextForSpeech` profiles are now persisted by the package when a runtime is configured with a `persistenceURL`.

Persistence is JSON-backed today through:

- `TextForSpeech.PersistedState`
- `TextForSpeech.PersistenceError`
- `TextForSpeech.Runtime.persistence.load()`
- `TextForSpeech.Runtime.persistence.save()`
- `TextForSpeech.Runtime.persistence.restore(_:)`

YAML and hot reload are still future work.

## What “slices” means today

There is still not a first-class public type literally named `Slice`.

But the slice-like structure is now public through:

- `TextForSpeech.ForensicFeatures`
- `TextForSpeech.Section`
- `TextForSpeech.SectionWindow`
- `TextForSpeech.Forensics.sections(originalText:)`
- `TextForSpeech.Forensics.sectionWindows(originalText:totalDurationMS:totalChunkCount:)`

Those APIs still behave like the first real draft of a slice system:

1. split by Markdown headers if present
2. otherwise split by paragraphs
3. otherwise fall back to one full-request section

## Practical mental model

The concise model to keep in your head is:

- `Context`
  Request-local environment and optional format hint.
- `TextFormat`
  The broad outer document family for the text lane.
- `SourceFormat`
  The explicit source-language family for the source lane.
- `profiles`
  The runtime profile capability handle.
- `profiles.active(id:)`
  The active editable custom layer for a runtime.
- `Replacement`
  One custom rewrite rule inside a profile.
- `profiles.effective(id:)`
  The built-in merged profile captured for one job.
- `persistence`
  The runtime persistence capability handle.
- `Section` and `SectionWindow`
  Public forensic structure that already behaves like the first draft of slices.
