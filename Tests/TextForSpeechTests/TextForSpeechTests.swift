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

// MARK: - Profiles

@Test func profileFiltersReplacementsByPhaseAndKind() {
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

// MARK: - Normalization

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
        kind: .plain
    )

    #expect(normalized.contains("chromatically"))
    #expect(normalized.contains("settings token"))
    #expect(!normalized.contains("c h r o m"))
    #expect(!normalized.contains("snake case stuff"))
}

// MARK: - Forensics

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
