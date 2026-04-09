# TextForSpeech Profiles and Replacements

## Why this exists

This note explains the current `TextForSpeech` model in maintainer terms, with special attention to the separation between:

- structural normalization logic
- built-in lexical normalization policy
- runtime-owned custom profile state
- forensic helpers

Those concerns deliberately live in different places now. The package is easier to reason about when maintainers keep those boundaries straight.

## Core model

The current package model is:

- `TextForSpeech.Profile.base`
  The static always-on built-in profile that ships with the package.
- stored custom profiles
  Named user- or app-owned profiles persisted by `TextForSpeech.Runtime`.
- active custom profile id
  The one stored custom profile currently selected by the runtime.
- effective profile
  The merged `base + active custom` profile used for runtime normalization work.

The simpler extension path considered first was keeping one loose active custom profile value beside a stored profile dictionary. That was rejected because it made bootstrap, active-profile identity, and persistence semantics harder to reason about. The runtime now treats the active custom layer as a stored profile selected by id.

## Profile type

`TextForSpeech.Profile` stays intentionally small:

- `id`
- `name`
- `replacements`

It does not carry request-local path context, detected formats, or runtime-owned persistence state. It answers the narrower question:

> "What reusable rewrite policy should apply around the structural normalizer?"

That keeps responsibilities clean:

- `TextForSpeech.Context` carries request-local environment such as `cwd`, `repoRoot`, and optional format hints.
- `TextForSpeech.Profile.base` carries the built-in replacement policy.
- `TextForSpeech.Profile` values also carry reusable custom replacement policy.
- `TextForSpeech.Runtime` owns persistence and active-profile selection.
- the normalizer owns structural document parsing and pipeline routing.

## Replacement type

`TextForSpeech.Replacement` describes one reusable rule. Each replacement captures:

- what shape to match
- when to run
- which text or source formats it applies to
- how to transform the matched content
- how strongly it should win relative to other rules

The current matching model supports:

- exact phrase matching
- whole-token matching
- token-kind matching
- line-kind matching

The current transform model supports:

- literal string replacement
- spoken path conversion
- spoken URL conversion
- spoken identifier conversion
- spoken code conversion
- spelling out repeated-letter-run tokens

## Pipeline phases

The phase split is still architecturally important.

`beforeBuiltIns` means:

- run this rule before the built-in lexical rules have finished rewriting the text
- use it when a caller needs to rename or protect raw source text before the built-in behavior touches it

`afterBuiltIns` means:

- run this rule after the built-in lexical behavior has already made the text more speakable
- use it for final-pass polish on the spoken output

## What lives in `Profile.base`

The built-in profile now carries the durable lexical policy that used to be spread through hard-coded helpers.

That includes:

- Gale alias replacements such as `galew` and `galem`
- spoken URL conversion
- spoken file-path conversion
- spoken dotted, snake_case, dashed, and camelCase identifier conversion
- line-based spoken code conversion for code-like text lines
- line-based spoken code conversion for whole-source input
- repeated-letter-run spelling

This change is a durable building-block change, not a cosmetic one. It unlocks inspectable built-in behavior, one merge story for base and custom rules, and better testability for shipped normalization policy.

## What stays structural in code

Not every behavior belongs in replacement data.

The normalizer still owns:

- fenced-code extraction
- inline-code extraction
- markdown-link parsing
- format detection
- path-context shortening such as `current directory` and `repo root`
- final whitespace cleanup

Those are document-structure or routing decisions rather than durable lexical policy. Treating them as replacement rules would make the system harder, not easier, to reason about.

## Runtime ownership

`TextForSpeech.Runtime` owns:

- `baseProfile`
- `persistenceURL`
- `activeCustomProfileID`
- `storedCustomProfilesByID`

Its public grouped surfaces are:

- `profiles`
- `persistence`

The runtime profile API now centers on:

- `profiles.activeID`
- `profiles.active()`
- `profiles.effective()`
- `profiles.effective(id:)`
- `profiles.stored(id:)`
- `profiles.list()`
- `profiles.activate(id:)`
- `profiles.store(_:)`
- `profiles.create(id:name:replacements:)`
- `profiles.delete(id:)`
- `profiles.add(_:)`
- `profiles.add(_:toProfileID:)`
- `profiles.replace(_:)`
- `profiles.replace(_:inProfileID:)`
- `profiles.removeReplacement(id:)`
- `profiles.removeReplacement(id:fromProfileID:)`
- `profiles.reset()`

The grouped persistence API centers on:

- `persistence.state`
- `persistence.load()`
- `persistence.load(from:)`
- `persistence.save()`
- `persistence.save(to:)`
- `persistence.restore(_:)`

## Bootstrap behavior

`TextForSpeech.Runtime()` is now throwing and persistence is default-on.

Startup behavior is:

1. resolve the persistence URL, defaulting to Application Support
2. load persisted state if the file exists
3. ensure a stored `default` custom profile exists
4. create and persist an empty `default` profile if it does not
5. ensure `activeCustomProfileID` points at a real stored profile
6. fall back to `default` if the saved active id is missing or invalid

The Application Support namespace uses the host bundle identifier when available and falls back to `TextForSpeech` when it is not.

## Practical maintainer rules

When touching profile behavior:

- put durable shipped lexical behavior into `Profile.base`
- put request-local behavior into `Context`
- keep structural parsing and routing logic in the normalizer
- keep persistence and active-profile selection in `Runtime`

When touching docs or tests:

- describe the active profile as a stored custom profile selected by id
- describe the effective profile as `base + active custom`
- do not describe `Profile.default` as the built-in always-on layer
- do not treat runtime persistence as caller-managed setup unless the caller explicitly overrides the path

## Related docs

- [README.md](../../README.md)
- [ROADMAP.md](../../ROADMAP.md)
- [textforspeech-split-plan.md](./textforspeech-split-plan.md)
