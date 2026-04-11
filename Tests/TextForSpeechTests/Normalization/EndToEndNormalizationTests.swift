import Testing
@testable import TextForSpeech

// MARK: - End-to-End Normalization

private func occurrenceCount(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
}

@Test func normalizePreservesMixedInputBehavior() {
    let original = """
    Please read /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift, NSApplication.didFinishLaunchingNotification, camelCaseStuff, snake_case_stuff, and `profile?.sampleRate ?? 24000`.
    """

    let normalized = TextForSpeech.Normalize.text(original)

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

    let normalized = TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("the docs, link example dot com slash docs"))
    #expect(normalized.contains("Code sample."))
    #expect(normalized.contains("slash tmp slash Thing"))
    #expect(normalized.contains("c h r o m m m a t i c a l l l y"))
}

@Test func normalizeHandlesStandaloneUrlsBeforePathPasses() {
    let original = "Open https://example.com/docs/path_now before /tmp/Thing."

    let normalized = TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("example dot com slash docs slash path now"))
    #expect(normalized.contains("tmp slash Thing"))
}

@Test func repeatedUnderscoresCollapseToSpeechSafeSpacing() {
    let original = "Read snake___case and /tmp/path___now once."

    let normalized = TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("snake case"))
    #expect(normalized.contains("tmp slash path now"))
    #expect(!normalized.contains("underscore"))
    #expect(!normalized.contains("___"))
}

@Test func repeatedDashesCollapseToSpeechSafeSpacing() {
    let original = "Read kebab---case and /tmp/path---now once."

    let normalized = TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("kebab case"))
    #expect(normalized.contains("tmp slash path now"))
    #expect(!normalized.contains("dash"))
    #expect(!normalized.contains("---"))
}

@Test func normalizeUsesContextAwareFilePathShortening() {
    let original = "Please read /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift."

    let normalized = TextForSpeech.Normalize.text(
        original,
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly"
        )
    )

    #expect(normalized.contains("current directory slash Sources slash Speak Swiftly"))
    #expect(!normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
}

@Test func normalizeCompactsRepeatedPathsInTheSameDirectory() {
    let original = """
    Compare /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift and /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/WorkerRuntime.swift.
    """

    let normalized = TextForSpeech.Normalize.text(
        original,
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly"
        )
    )

    let sharedPrefix = "current directory slash Sources slash Speak Swiftly"
    #expect(occurrenceCount(of: sharedPrefix, in: normalized) == 1)
    #expect(normalized.contains("Speech Text Normalizer dot swift"))
    #expect(normalized.contains("same directory, Worker Runtime dot swift"))
}

@Test func normalizeCompactsRepeatedExactPaths() {
    let original = """
    Read /tmp/Thing.swift, then read /tmp/Thing.swift again.
    """

    let normalized = TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("tmp slash Thing dot swift"))
    #expect(normalized.contains("same path"))
    #expect(occurrenceCount(of: "tmp slash Thing dot swift", in: normalized) == 1)
}

@Test func normalizeAppliesCustomReplacementsAroundBuiltIns() {
    let profile = TextForSpeech.Profile(
        id: "custom",
        name: "Custom",
        replacements: [
            TextForSpeech.Replacement(
                "chrommmaticallly",
                with: "chromatically",
                during: .beforeBuiltIns
            ),
            TextForSpeech.Replacement(
                "snake case stuff",
                with: "settings token",
                during: .afterBuiltIns,
                forTextFormats: [.plain]
            ),
        ]
    )

    let normalized = TextForSpeech.Normalize.text(
        "Please say chrommmaticallly and snake_case_stuff once.",
        customProfile: profile,
        format: .plain
    )

    #expect(normalized.contains("chromatically"))
    #expect(normalized.contains("settings token"))
    #expect(!normalized.contains("c h r o m"))
    #expect(!normalized.contains("snake case stuff"))
}

@Test func detectTextFormatFindsMarkdown() {
    let markdown = """
    # Header

    Read `code` and [docs](https://example.com).
    """

    #expect(TextForSpeech.Normalize.detectTextFormat(in: markdown) == .markdown)
}

@Test func detectTextFormatFindsListHtmlCliAndLogInputs() {
    let list = """
    - First
    - Second
    """
    let html = "<div><p>Hello</p></div>"
    let cli = "$ swift test"
    let log = "2026-04-05 18:00:00 ERROR Worker failed"

    #expect(TextForSpeech.Normalize.detectTextFormat(in: list) == .list)
    #expect(TextForSpeech.Normalize.detectTextFormat(in: html) == .html)
    #expect(TextForSpeech.Normalize.detectTextFormat(in: cli) == .cli)
    #expect(TextForSpeech.Normalize.detectTextFormat(in: log) == .log)
}

@Test func contextFormatOverridesAutomaticDetection() {
    let text = """
    # Header

    - First
    - Second
    """

    let normalized = TextForSpeech.Normalize.text(
        text,
        context: TextForSpeech.Context(textFormat: .list)
    )

    #expect(normalized.contains("Header"))
}

@Test func normalizeTextUsesNestedFormatForEmbeddedSwiftCode() {
    let original = """
    ```swift
    let sampleRate = profile?.sampleRate ?? 24000
    ```
    """

    let normalized = TextForSpeech.Normalize.text(
        original,
        format: .markdown,
        nestedFormat: .swift
    )

    #expect(normalized.contains("Code sample."))
    #expect(normalized.contains("optional chaining"))
    #expect(normalized.contains("nil coalescing"))
}

@Test func normalizeTextUsesNestedSourceFormatFromContext() {
    let original = """
    ```swift
    let sampleRate = profile?.sampleRate ?? 24000
    ```
    """

    let normalized = TextForSpeech.Normalize.text(
        original,
        context: TextForSpeech.Context(
            textFormat: .markdown,
            nestedSourceFormat: .swift
        )
    )

    #expect(normalized.contains("optional chaining"))
    #expect(normalized.contains("nil coalescing"))
}

@Test func normalizeSourceProvidesExplicitWholeSourceLane() {
    let source = """
    struct WorkerRuntime {
        let sampleRate: Int
    }
    """

    let normalized = TextForSpeech.Normalize.source(source, as: .swift)

    #expect(normalized.contains("open brace"))
    #expect(normalized.contains("sample Rate"))
}

@Test func compactStyleKeepsWholeSourceMoreVisualAndLessSpoken() {
    let source = """
    struct WorkerRuntime {
        let sampleRate: Int
    }
    """

    let normalized = TextForSpeech.Normalize.source(
        source,
        as: .swift,
        style: .compact
    )

    #expect(!normalized.contains("open brace"))
    #expect(normalized.contains("sample Rate"))
}

@Test func stylesDifferentiateFunctionCallsIssueReferencesFlagsAndFileRefs() {
    let original = "Run foo() with --help and see #123 in WorkerRuntime.swift:42:7."

    let compact = TextForSpeech.Normalize.text(
        original,
        style: .compact,
        format: .plain
    )
    let balanced = TextForSpeech.Normalize.text(
        original,
        style: .balanced,
        format: .plain
    )
    let explicit = TextForSpeech.Normalize.text(
        original,
        style: .explicit,
        format: .plain
    )

    #expect(compact.contains("foo"))
    #expect(!compact.contains("function call"))
    #expect(compact.contains("help"))
    #expect(!compact.contains("dash dash help"))
    #expect(compact.contains("123"))
    #expect(!compact.contains("issue 123"))

    #expect(balanced.contains("foo function"))
    #expect(balanced.contains("dash dash help"))
    #expect(balanced.contains("issue 123"))
    #expect(balanced.contains("Worker Runtime dot swift line 42 column 7"))

    #expect(explicit.contains("foo function call"))
    #expect(explicit.contains("long flag help"))
    #expect(explicit.contains("issue number 123"))
    #expect(explicit.contains("file Worker Runtime dot swift line 42 column 7"))
}
