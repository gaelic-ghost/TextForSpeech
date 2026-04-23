# TextForSpeech Profiles and Replacements

## Why this exists

This note explains the current `TextForSpeech` model in maintainer terms, with special attention to the separation between:

- structural normalization logic
- built-in lexical normalization policy
- runtime-owned custom profile state

Those concerns deliberately live in different places now. The package is easier to reason about when maintainers keep those boundaries straight.

## Core model

The current package model is:

- `TextForSpeech.Profile.semanticCore`
  The always-on built-in semantic layer.
- `TextForSpeech.BuiltInProfileStyle`
  The shipped style preset selector.
- `TextForSpeech.Profile.builtInBase(style:)`
  The composed built-in base for one style.
- stored custom profiles
  Named user- or app-owned profiles persisted by `TextForSpeech.Runtime`.
- built-in style
  The one shipped style preset currently selected by the runtime.
- active custom profile id
  The one stored custom profile currently selected by the runtime.
- effective profile
  The merged `built-in base + active custom` profile used for runtime normalization work.

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
- `TextForSpeech.RequestContext` carries optional request-origin metadata such as `source`, `app`, `agent`, `project`, `topic`, and freeform string attributes.
- `TextForSpeech.Profile.semanticCore` carries the always-on semantic built-in policy.
- `TextForSpeech.Profile.builtInStyle(_:)` carries shipped presentation policy for one listening style.
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

## What lives in the built-in profile layers

The built-in layers now carry the durable lexical policy that used to be spread through hard-coded helpers.

The semantic core currently includes:

- Gale alias replacements such as `galew` and `galem`
- currency amount speaking such as `$9.39` -> `nine dollars and thirty-nine cents`
- measured-value speaking such as `42 km` -> `forty-two kilometers` and `64Gbps` -> `sixty four gigabits per second`
- extension aliases for hard-to-speak file types such as `.xcodeproj`, `.pbxproj`, `.xcworkspace`, `.xcconfig`, `.xcscheme`, `.xctestplan`, `.xcresult`, `.xcassets`, `.xcstrings`, `.xcprivacy`, `.dSYM`, `.mdx`, `.tsx`, `.jsx`, `.jsonc`, `.ipynb`, `.wasm`, `.sqlite`, and `.db`
- spoken URL conversion
- spoken file-path conversion
- spoken dotted, snake_case, dashed, and camelCase identifier conversion
- repeated-letter-run spelling

The semantic core is now split by semantic role under `Sources/TextForSpeech/Models/BuiltInProfiles/`:

- `BuiltInSemanticAliases.swift`
  Stable lexical aliases for names that should be rewritten before broader token transforms.
- `BuiltInScalarPronunciations.swift`
  Whole-token scalar-width pronunciations such as `f32` and `usize`.
- `BuiltInExtensionAliases.swift`
  Literal extension aliases for suffixes that are too dense or awkward to read raw.
- `BuiltInTokenTransforms.swift`
  Broader spoken transforms for paths, URLs, identifiers, and repeated-letter runs.
- `BuiltInStylePresets.swift`
  Presentation-only shipped style presets such as `.balanced`, `.compact`, and `.explicit`.

The balanced style layer currently includes:

- line-based spoken code conversion for code-like text lines
- line-based spoken code conversion for whole-source input
- function-call speaking such as `foo()` -> `foo function`
- issue-reference speaking such as `#123` -> `issue 123`
- file-line-reference speaking such as `WorkerRuntime.swift:42:7` -> `Worker Runtime dot swift line 42 column 7`
- CLI-flag speaking such as `--help` -> `double tack help`
- matched brace, bracket, and parenthesis pairs are omitted inside the spoken-code lane so structural wrappers do not drown out the actual code content, while unmatched delimiters are still narrated

The compact style currently:

- drops those line-based spoken-code rules so source-like text stays more visual and less expanded
- compresses function calls such as `foo()` -> `foo`
- compresses issue references such as `#123` -> `123`
- compresses file references such as `WorkerRuntime.swift:42:7` -> `Worker Runtime dot swift 42 7`
- compresses CLI flags such as `--help` -> `help`

The explicit style currently:

- keeps the same line-based spoken-code rules as the balanced style
- expands function calls such as `foo()` -> `foo function call`
- expands issue references such as `#123` -> `issue number 123`
- expands file references such as `WorkerRuntime.swift:42:7` -> `file Worker Runtime dot swift line 42 column 7`
- expands CLI flags such as `--help` -> `long flag help`

This change is a durable building-block change, not a cosmetic one. It unlocks inspectable built-in behavior, one merge story for base and custom rules, and better testability for shipped normalization policy.

## What stays structural in code

Not every behavior belongs in replacement data.

The normalizer still owns:

- fenced-code extraction
- inline-code extraction
- markdown-link parsing
- list-prefix parsing for structural markers such as priority tags like `[P1]`
- format detection
- path-context shortening such as `current directory` and `repo root`
- final whitespace cleanup that preserves explicit line and paragraph breaks

Those are document-structure or routing decisions rather than durable lexical policy. Treating them as replacement rules would make the system harder, not easier, to reason about.

## File-path invariant

For file paths, the required spoken behavior is:

- collapse path separators to spacing rather than saying `slash` or `backslash`
- keep extension narration such as `dot swift`
- keep path-context shortening such as `current directory` and `repo root`
- preserve the path-specific lane even when a path appears inside markdown inline code or fenced code

This package exists to reduce downstream TTS damage for developer text, so maintainers should treat spoken separator words inside file paths as a regression unless a caller explicitly asks for separator narration.

## Runtime ownership

`TextForSpeech.Runtime` owns:

- `baseProfile`
- `builtInStyle`
- `persistenceConfiguration`
- `activeCustomProfileID`
- `storedCustomProfilesByID`

Its public grouped surfaces are:

- `profiles`
- `style`
- `normalize`
- `persistence`

The runtime profile API now centers on:

- `profiles.getActive()`
- `profiles.getEffective()`
- `profiles.get(id:)`
- `profiles.list()`
- `profiles.setActive(id:)`
- `profiles.create(name:)`
- `profiles.rename(profile:to:)`
- `profiles.delete(id:)`
- `profiles.addReplacement(_:)`
- `profiles.addReplacement(_:toProfile:)`
- `profiles.patchReplacement(_:)`
- `profiles.patchReplacement(_:inProfile:)`
- `profiles.removeReplacement(id:)`
- `profiles.removeReplacement(id:fromProfile:)`
- `profiles.factoryReset()`
- `profiles.reset(id:)`

The runtime style API now centers on:

- `style.getActive()`
- `style.list()`
- `style.setActive(to:)`

The runtime normalization API now centers on:

- `normalize.text(_:)`
- `normalize.text(_:usingProfileID:)`
- `normalize.source(_:as:)`
- `normalize.source(_:as:usingProfileID:)`

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

1. resolve the persistence configuration, defaulting to `.default`
2. resolve the effective persistence URL from that configuration
3. load persisted state if the file exists
4. restore the persisted built-in style, defaulting to `.balanced` when older archives do not contain it
5. ensure a stored `default` custom profile exists
6. create and persist an empty `default` profile if it does not
7. ensure `activeCustomProfileID` points at a real stored profile
8. fall back to `default` if the saved active id is missing or invalid

The default Application Support namespace uses the host bundle identifier when available and falls back to `TextForSpeech` when it is not. In debug builds for bundled targets, the default package directory name changes to `TextForSpeech-Debug` so debug sessions do not write into the bundled production namespace.

## Practical maintainer rules

When touching profile behavior:

- put always-on semantic shipped behavior into `Profile.semanticCore`
- put built-in presentation differences into shipped style presets
- put request-local behavior into `Context`
- keep structural parsing and routing logic in the normalizer
- keep persistence and active-profile selection in `Runtime`

When deciding where a new built-in rule belongs:

- use `BuiltInSemanticAliases.swift` when the text should always collapse to one stable spoken name before any other semantic pass
- use `BuiltInScalarPronunciations.swift` when the rule is a durable whole-token pronunciation for terse typed-width or numeric forms
- use `BuiltInExtensionAliases.swift` when the main problem is a raw file suffix that sounds bad before path or file-reference narration
- use `BuiltInTokenTransforms.swift` when the rule is broad token-shape behavior rather than one literal vocabulary entry
- use `BuiltInStylePresets.swift` only when the behavior is presentation policy and callers should be able to switch between `.balanced`, `.compact`, and `.explicit` without changing the underlying semantics
- keep structural markdown, parsing, routing, or context-sensitive behavior out of these fragments and in `Normalization/`

When touching docs or tests:

- describe the active profile as a stored custom profile selected by id
- describe the effective profile as `builtInBase(style: builtInStyle) + active custom`
- do not describe `Profile.default` as the built-in always-on layer
- do not treat runtime persistence as caller-managed setup unless the caller explicitly overrides the default configuration with `.file(url)`

## Related docs

- [README.md](../../README.md)
- [ROADMAP.md](../../ROADMAP.md)
- [textforspeech-split-plan.md](./textforspeech-split-plan.md)
