import Foundation
import Testing
@testable import TextForSpeech

// MARK: - Runtime

@Test func runtimeMergesBaseAndCustomProfilesForSnapshots() {
    let runtime = TextForSpeechRuntime(
        baseProfile: TextForSpeech.Profile(
            id: "base",
            name: "Base",
            replacements: [
                TextForSpeech.Replacement("foo", with: "bar", id: "base-rule")
            ]
        ),
        customProfile: TextForSpeech.Profile(
            id: "custom",
            name: "Custom",
            replacements: [
                TextForSpeech.Replacement("bar", with: "baz", id: "custom-rule")
            ]
        )
    )

    let snapshot = runtime.snapshot()

    #expect(snapshot.id == "custom")
    #expect(snapshot.name == "Custom")
    #expect(snapshot.replacements.map(\.id) == ["base-rule", "custom-rule"])
}

@Test func runtimeReturnsStableSnapshotsForLaterJobs() {
    let runtime = TextForSpeechRuntime(
        customProfile: TextForSpeech.Profile(
            id: "default",
            name: "Default",
            replacements: [
                TextForSpeech.Replacement("foo", with: "bar")
            ]
        )
    )

    let firstSnapshot = runtime.snapshot()
    runtime.use(
        TextForSpeech.Profile(
            id: "default",
            name: "Updated",
            replacements: [
                TextForSpeech.Replacement("foo", with: "baz")
            ]
        )
    )
    let secondSnapshot = runtime.snapshot()

    #expect(firstSnapshot.name == "Default")
    #expect(firstSnapshot.replacements.last?.replacement == "bar")
    #expect(secondSnapshot.name == "Updated")
    #expect(secondSnapshot.replacements.last?.replacement == "baz")
}

@Test func runtimeCanSnapshotStoredNamedProfiles() {
    let runtime = TextForSpeechRuntime()
    let logsProfile = TextForSpeech.Profile(
        id: "logs",
        name: "Logs",
        replacements: [
            TextForSpeech.Replacement("stderr", with: "standard error", id: "logs-rule")
        ]
    )

    runtime.store(logsProfile)
    let snapshot = runtime.snapshot(named: "logs")

    #expect(snapshot.id == "logs")
    #expect(snapshot.replacements.map(\.id) == ["logs-rule"])
}

@Test func runtimeCreatesProfilesAndListsThemInStableOrder() throws {
    let runtime = TextForSpeechRuntime()

    let zebra = try runtime.createProfile(id: "zebra", named: "Zebra")
    let alpha = try runtime.createProfile(id: "alpha", named: "Alpha")

    #expect(zebra.id == "zebra")
    #expect(alpha.name == "Alpha")
    #expect(runtime.storedProfiles().map(\.id) == ["alpha", "zebra"])
}

@Test func runtimeEditsCustomAndStoredProfileReplacements() throws {
    let runtime = TextForSpeechRuntime(
        customProfile: TextForSpeech.Profile(
            id: "default",
            name: "Default",
            replacements: [
                TextForSpeech.Replacement("stderr", with: "standard error", id: "stderr-rule")
            ]
        )
    )
    _ = try runtime.createProfile(id: "logs", named: "Logs")

    let customProfile = runtime.addReplacement(
        TextForSpeech.Replacement("stdout", with: "standard output", id: "stdout-rule")
    )
    #expect(customProfile.replacements.map(\.id) == ["stderr-rule", "stdout-rule"])

    let storedProfile = try runtime.addReplacement(
        TextForSpeech.Replacement("panic", with: "runtime panic", id: "panic-rule"),
        toStoredProfileNamed: "logs"
    )
    #expect(storedProfile.replacements.map(\.id) == ["panic-rule"])

    let replacedProfile = try runtime.replaceReplacement(
        TextForSpeech.Replacement("panic", with: "fatal runtime panic", id: "panic-rule"),
        inStoredProfileNamed: "logs"
    )
    #expect(replacedProfile.replacements.first?.replacement == "fatal runtime panic")

    let trimmedProfile = try runtime.removeReplacement(
        id: "panic-rule",
        fromStoredProfileNamed: "logs"
    )
    #expect(trimmedProfile.replacements.isEmpty)
}

@Test func runtimeSavesAndLoadsPersistedProfiles() throws {
    let directoryURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
    let fileURL = directoryURL.appending(path: "text-profiles.json")
    defer { try? FileManager.default.removeItem(at: directoryURL) }

    let writer = TextForSpeechRuntime(persistenceURL: fileURL)
    writer.store(
        TextForSpeech.Profile(
            id: "logs",
            name: "Logs",
            replacements: [
                TextForSpeech.Replacement("stderr", with: "standard error", id: "logs-rule")
            ]
        )
    )
    writer.use(
        TextForSpeech.Profile(
            id: "ops",
            name: "Ops",
            replacements: [
                TextForSpeech.Replacement("stdout", with: "standard output", id: "ops-rule")
            ]
        )
    )

    try writer.save()

    let reader = TextForSpeechRuntime(persistenceURL: fileURL)
    try reader.load()

    #expect(reader.customProfile.id == "ops")
    #expect(reader.customProfile.replacements.map(\.id) == ["ops-rule"])
    #expect(reader.profile(named: "logs")?.replacements.map(\.id) == ["logs-rule"])
}

@Test func runtimeRestoreRejectsUnsupportedPersistedStateVersion() {
    let runtime = TextForSpeechRuntime()

    #expect(throws: TextForSpeech.PersistenceError.self) {
        try runtime.restore(
            TextForSpeech.PersistedState(
                version: 99,
                customProfile: .default,
                profiles: [:]
            )
        )
    }
}

// MARK: - Profiles

@Test func profileFiltersReplacementsByPhaseAndFormat() {
    let profile = TextForSpeech.Profile(
        replacements: [
            TextForSpeech.Replacement(
                "Thing",
                with: "Swift thing",
                id: "swift",
                in: .beforeNormalization,
                for: [.swift]
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Any source thing",
                id: "source",
                in: .beforeNormalization,
                for: [.source],
                priority: 10
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Final thing",
                id: "final",
                in: .afterNormalization
            ),
        ]
    )

    let beforeNormalization = profile.replacements(for: .beforeNormalization, in: .swift)
    let afterNormalization = profile.replacements(for: .afterNormalization, in: .swift)

    #expect(beforeNormalization.map(\.id) == ["source", "swift"])
    #expect(afterNormalization.map(\.id) == ["final"])
}

@Test func baseProfileAndDefaultProfileStayDistinct() {
    #expect(TextForSpeech.Profile.base.id == "base")
    #expect(TextForSpeech.Profile.default.id == "default")
    #expect(TextForSpeech.Profile.base.name == "Base")
    #expect(TextForSpeech.Profile.default.name == "Default")
}

// MARK: - Markdown and URL Handling

@Test func fencedCodeBlocksBecomeSpokenCodeSamples() {
    let text = """
    Before
    ```swift
    let fooBar = thing?.value ?? 24000
    ```
    After
    """

    let normalized = TextNormalizer.normalizeFencedCodeBlocks(text)

    #expect(normalized.contains("Code sample."))
    #expect(normalized.contains("let foo Bar equals thing optional chaining value nil coalescing 24000"))
    #expect(normalized.contains("End code sample."))
}

@Test func inlineCodeSpansBecomeSpeakable() {
    let text = "Read `profile?.sampleRate ?? 24000` once."

    let normalized = TextNormalizer.normalizeInlineCodeSpans(text)

    #expect(!normalized.contains("`"))
    #expect(normalized.contains("profile optional chaining sample Rate nil coalescing 24000"))
}

@Test func markdownLinksPreserveLabelAndDestination() {
    let text = "Open [the docs](https://example.com/docs) now."

    let normalized = TextNormalizer.normalizeMarkdownLinks(text)

    #expect(normalized.contains("the docs, link https://example.com/docs"))
}

@Test func urlsBecomeSpokenUrls() {
    let text = "Open https://example.com/docs now."

    let normalized = TextNormalizer.normalizeURLs(text)

    #expect(normalized.contains("example dot com slash docs"))
    #expect(!normalized.contains("https"))
}

@Test func urlsOmitLeadingWWW() {
    let text = "Open https://www.example.com/docs now."

    let normalized = TextNormalizer.normalizeURLs(text)

    #expect(normalized.contains("example dot com slash docs"))
    #expect(!normalized.contains("www"))
}

@Test func nonHTTPURLsKeepTheirScheme() {
    let text = "Open file://tmp/Thing now."

    let normalized = TextNormalizer.normalizeURLs(text)

    #expect(normalized.contains("file colon slash slash tmp slash Thing"))
}

// MARK: - File Paths and Names

@Test func filePathsBecomeSpokenPaths() {
    let text = "Path: /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift."

    let normalized = TextNormalizer.normalizeFilePaths(text)

    #expect(normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
    #expect(normalized.contains("Speech Text Normalizer dot swift"))
}

@Test func filePathsUseConfiguredGaleAliases() {
    let text = "Path: /Users/galem/Workspace/SpeakSwiftly."

    let normalized = TextNormalizer.normalizeFilePaths(text)

    #expect(normalized.contains("gale mini slash Workspace slash Speak Swiftly"))
}

@Test func dashedFilePathsBecomeSpeechSafeSpacing() {
    let text = "Path: /tmp/speak-to-user/path-now."

    let normalized = TextNormalizer.normalizeFilePaths(text)

    #expect(normalized.contains("tmp slash speak to user slash path now"))
    #expect(!normalized.contains("dash"))
}

@Test func filePathsInsideCurrentDirectoryOmitTheAbsolutePrefix() {
    let text = "Path: /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift."

    let normalized = TextNormalizer.normalizeFilePaths(
        text,
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly"
        )
    )

    #expect(normalized.contains("current directory slash Sources slash Speak Swiftly"))
    #expect(normalized.contains("Speech Text Normalizer dot swift"))
    #expect(!normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
}

@Test func filePathsInsideRepoRootButOutsideCurrentDirectoryKeepRepoRootContext() {
    let text = "Path: /Users/galew/Workspace/SpeakSwiftly/README.md."

    let normalized = TextNormalizer.normalizeFilePaths(
        text,
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly"
        )
    )

    #expect(normalized.contains("repo root slash README dot md"))
    #expect(!normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
}

@Test func standaloneGaleAliasesBecomeSpokenNames() {
    let text = "Please ask galew, galem, and Galew again."

    let normalized = TextNormalizer.normalizeStandaloneGaleAliases(text)

    #expect(normalized.contains("gale wumbo"))
    #expect(normalized.contains("gale mini"))
    #expect(normalized.contains("gale wumbo"))
}

// MARK: - Identifier and Code Speech

@Test func dottedIdentifiersBecomeSpokenIdentifiers() {
    let text = "Read NSApplication.didFinishLaunchingNotification once."

    let normalized = TextNormalizer.normalizeDottedIdentifiers(text)

    #expect(normalized.contains("NSApplication dot did Finish Launching Notification"))
}

@Test func snakeCaseIdentifiersBecomeSpokenIdentifiers() {
    let text = "Read snake_case_stuff once."

    let normalized = TextNormalizer.normalizeSnakeCaseIdentifiers(text)

    #expect(normalized.contains("snake case stuff"))
    #expect(!normalized.contains("underscore"))
}

@Test func dashedIdentifiersBecomeSpeechSafeSpacing() {
    let normalized = TextNormalizer.spokenIdentifier("kebab-case-stuff")

    #expect(normalized.contains("kebab case stuff"))
    #expect(!normalized.contains("dash"))
}

@Test func camelCaseIdentifiersBecomeSpokenIdentifiers() {
    let text = "Read camelCaseStuff once."

    let normalized = TextNormalizer.normalizeCamelCaseIdentifiers(text)

    #expect(normalized.contains("camel Case Stuff"))
}

@Test func codeHeavyLinesBecomeSpokenCode() {
    let text = #"let fallback = weirdWords.first(where: { $0.hasPrefix("q") }) ?? "nothing""#

    let normalized = TextNormalizer.normalizeCodeHeavyLines(text)

    #expect(normalized.contains("open brace"))
    #expect(normalized.contains("nil coalescing"))
}

@Test func spiralProneWordsAreSpelledOut() {
    let text = "Also say chrommmaticallly and qqqwweerrtyy once."

    let normalized = TextNormalizer.normalizeSpiralProneWords(text)

    #expect(normalized.contains("c h r o m m m a t i c a l l l y"))
    #expect(normalized.contains("q q q w w e e r r t y y"))
}

// MARK: - End-to-End Normalization

@Test func normalizePreservesMixedInputBehavior() {
    let original = """
    Please read /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift, NSApplication.didFinishLaunchingNotification, camelCaseStuff, snake_case_stuff, and `profile?.sampleRate ?? 24000`.
    """

    let normalized = TextForSpeech.normalize(original)

    #expect(normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
    #expect(normalized.contains("NSApplication dot did Finish Launching Notification"))
    #expect(normalized.contains("camel Case Stuff"))
    #expect(normalized.contains("snake case stuff"))
    #expect(normalized.contains("profile optional chaining sample Rate nil coalescing 24000"))
}

@Test func normalizePreservesMarkdownLinksCodeBlocksAndSpiralWords() {
    let original = """
    Read [the docs](https://example.com/docs) first.

    ```swift
    let sourcePath = "/tmp/Thing"
    ```

    Also say chrommmaticallly once.
    """

    let normalized = TextForSpeech.normalize(original)

    #expect(normalized.contains("the docs, link example dot com slash docs"))
    #expect(normalized.contains("Code sample."))
    #expect(normalized.contains("slash tmp slash Thing"))
    #expect(normalized.contains("c h r o m m m a t i c a l l l y"))
}

@Test func normalizeHandlesStandaloneUrlsBeforePathPasses() {
    let original = "Open https://example.com/docs/path_now before /tmp/Thing."

    let normalized = TextForSpeech.normalize(original)

    #expect(normalized.contains("example dot com slash docs slash path now"))
    #expect(normalized.contains("tmp slash Thing"))
}

@Test func repeatedUnderscoresCollapseToSpeechSafeSpacing() {
    let original = "Read snake___case and /tmp/path___now once."

    let normalized = TextForSpeech.normalize(original)

    #expect(normalized.contains("snake case"))
    #expect(normalized.contains("tmp slash path now"))
    #expect(!normalized.contains("underscore"))
    #expect(!normalized.contains("___"))
}

@Test func repeatedDashesCollapseToSpeechSafeSpacing() {
    let original = "Read kebab---case and /tmp/path---now once."

    let normalized = TextForSpeech.normalize(original)

    #expect(normalized.contains("kebab case"))
    #expect(normalized.contains("tmp slash path now"))
    #expect(!normalized.contains("dash"))
    #expect(!normalized.contains("---"))
}

@Test func normalizeUsesContextAwareFilePathShortening() {
    let original = "Please read /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift."

    let normalized = TextForSpeech.normalize(
        original,
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly"
        )
    )

    #expect(normalized.contains("current directory slash Sources slash Speak Swiftly"))
    #expect(!normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
}

@Test func normalizeAppliesCustomReplacementsAroundBuiltIns() {
    let profile = TextForSpeech.Profile(
        id: "custom",
        name: "Custom",
        replacements: [
            TextForSpeech.Replacement(
                "chrommmaticallly",
                with: "chromatically",
                in: .beforeNormalization
            ),
            TextForSpeech.Replacement(
                "snake case stuff",
                with: "settings token",
                in: .afterNormalization,
                for: [.plain]
            ),
        ]
    )

    let normalized = TextForSpeech.normalize(
        "Please say chrommmaticallly and snake_case_stuff once.",
        profile: profile,
        as: .plain
    )

    #expect(normalized.contains("chromatically"))
    #expect(normalized.contains("settings token"))
    #expect(!normalized.contains("c h r o m"))
    #expect(!normalized.contains("snake case stuff"))
}

@Test func detectFormatFindsMarkdownAndSwiftSource() {
    let markdown = """
    # Header

    Read `code` and [docs](https://example.com).
    """
    let swift = """
    import Foundation

    struct Thing {
        let value: String
    }
    """

    #expect(TextForSpeech.detectFormat(in: markdown) == .markdown)
    #expect(TextForSpeech.detectFormat(in: swift) == .swift)
}

@Test func contextFormatOverridesAutomaticDetection() {
    let text = """
    # Header

    - First
    - Second
    """

    let normalized = TextForSpeech.normalize(
        text,
        context: TextForSpeech.Context(format: .list)
    )

    #expect(normalized.contains("Header"))
}

// MARK: - Forensics

@Test func forensicFeaturesCaptureCodeHeavyAndWeirdTextShapes() {
    let original = """
    # Header

    The path is /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift and the symbol is NSApplication.didFinishLaunchingNotification.

    Please read `dot.syntax.stuff`, camelCaseStuff, snake_case_stuff, [a markdown link](https://example.com/docs), and https://example.com/reference.

    ```objc
    @property(nonatomic, strong) NSString *displayName;
    [NSFileManager.defaultManager fileExistsAtPath:@"/tmp/Thing"];
    ```

    Also say chrommmaticallly and qqqwweerrtyy once.
    """

    let normalized = TextForSpeech.normalize(original)
    let features = TextForSpeech.forensicFeatures(originalText: original, normalizedText: normalized)

    #expect(features.originalCharacterCount > 0)
    #expect(features.normalizedCharacterCount > 0)
    #expect(features.markdownHeaderCount == 1)
    #expect(features.fencedCodeBlockCount == 1)
    #expect(features.inlineCodeSpanCount >= 1)
    #expect(features.markdownLinkCount == 1)
    #expect(features.urlCount >= 1)
    #expect(features.filePathCount >= 2)
    #expect(features.dottedIdentifierCount >= 1)
    #expect(features.camelCaseTokenCount >= 1)
    #expect(features.snakeCaseTokenCount >= 1)
    #expect(features.objcSymbolCount >= 1)
    #expect(features.repeatedLetterRunCount >= 2)
}

@Test func forensicSectionsPreferMarkdownHeaders() {
    let original = """
    # Intro
    One paragraph.

    ## Details
    Another paragraph.
    """

    let sections = TextForSpeech.sections(originalText: original)

    #expect(sections.count == 2)
    #expect(sections.map(\.kind) == [.markdownHeader, .markdownHeader])
    #expect(sections.map(\.title) == ["Intro", "Details"])
}

@Test func forensicSectionsAndWindowsTrackSegmentedMarkdownStructure() {
    let original = """
    # Section One

    Please read this paragraph once and keep a natural tone.

    ## Section Two

    Read these identifiers carefully: NSApplication.didFinishLaunchingNotification, camelCaseStuff, snake_case_stuff, and `profile?.sampleRate ?? 24000`.

    ## Section Three

    ```objc
    @property(nonatomic, strong) NSString *displayName;
    [NSFileManager.defaultManager fileExistsAtPath:@"/tmp/Thing"];
    ```

    ## Footer

    End this probe clearly and without looping.
    """

    let sections = TextForSpeech.sections(originalText: original)
    #expect(sections.map(\.title) == ["Section One", "Section Two", "Section Three", "Footer"])
    #expect(sections.allSatisfy { $0.kind == .markdownHeader })
    #expect(sections.allSatisfy { $0.normalizedCharacterCount > 0 })
    #expect(abs(sections.map(\.normalizedCharacterShare).reduce(0, +) - 1.0) < 0.0001)

    let windows = TextForSpeech.sectionWindows(
        originalText: original,
        totalDurationMS: 12_000,
        totalChunkCount: 75
    )
    #expect(windows.count == 4)
    #expect(windows.first?.estimatedStartMS == 0)
    #expect(windows.first?.estimatedStartChunk == 0)
    #expect(windows.last?.estimatedEndMS == 12_000)
    #expect(windows.last?.estimatedEndChunk == 75)
    #expect(
        zip(windows, windows.dropFirst()).allSatisfy { lhs, rhs in
            lhs.estimatedEndMS == rhs.estimatedStartMS
                && lhs.estimatedEndChunk == rhs.estimatedStartChunk
        }
    )
}

@Test func sectionWindowsCoverWholeDurationAndChunkCount() {
    let original = """
    Paragraph one.

    Paragraph two.
    """

    let windows = TextForSpeech.sectionWindows(
        originalText: original,
        totalDurationMS: 1000,
        totalChunkCount: 10
    )

    #expect(windows.count == 2)
    #expect(windows.first?.estimatedStartMS == 0)
    #expect(windows.last?.estimatedEndMS == 1000)
    #expect(windows.last?.estimatedEndChunk == 10)
}
