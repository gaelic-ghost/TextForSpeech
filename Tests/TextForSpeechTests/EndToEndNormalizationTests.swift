import Testing
@testable import TextForSpeech

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
