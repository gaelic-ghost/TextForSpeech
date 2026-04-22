import Testing
@testable import TextForSpeech

// MARK: - End-to-End Normalization

private func occurrenceCount(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
}

@Test func `normalize preserves mixed input behavior`() {
    let original = """
    Please read /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift, NSApplication.didFinishLaunchingNotification, camelCaseStuff, snake_case_stuff, f32, cosF32, and `profile?.sampleRate ?? 24000`.
    """

    let normalized = TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("gale wumbo Workspace Speak Swiftly"))
    #expect(normalized.contains("NSApplication dot did Finish Launching Notification"))
    #expect(normalized.contains("camel Case Stuff"))
    #expect(normalized.contains("snake case stuff"))
    #expect(normalized.contains("float thirty two"))
    #expect(normalized.contains("cosine float thirty two"))
    #expect(normalized.contains("profile optional chaining sample Rate nil coalescing 24000"))
}

@Test func `normalize accepts request context without changing output`() {
    let original = "Read /tmp/Thing.swift and `profile?.sampleRate ?? 24000`."

    let normalized = TextForSpeech.Normalize.text(
        original,
        requestContext: TextForSpeech.RequestContext(
            source: "codex",
            app: "SpeakSwiftly",
            project: "TextForSpeech",
            attributes: ["surface": "tests"],
        ),
    )

    #expect(normalized.contains("tmp Thing dot swift"))
    #expect(normalized.contains("profile optional chaining sample Rate nil coalescing 24000"))
}

@Test func `normalize preserves markdown links code blocks and spiral words`() {
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

@Test func `normalize handles standalone urls before path passes`() {
    let original = "Open https://example.com/docs/path_now before /tmp/Thing."

    let normalized = TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("example dot com slash docs slash path now"))
    #expect(normalized.contains("tmp Thing"))
}

@Test func `repeated underscores collapse to speech safe spacing`() {
    let original = "Read snake___case and /tmp/path___now once."

    let normalized = TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("snake case"))
    #expect(normalized.contains("tmp path now"))
    #expect(!normalized.contains("underscore"))
    #expect(!normalized.contains("___"))
}

@Test func `repeated dashes collapse to speech safe spacing`() {
    let original = "Read kebab---case and /tmp/path---now once."

    let normalized = TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("kebab case"))
    #expect(normalized.contains("tmp path now"))
    #expect(!normalized.contains("dash"))
    #expect(!normalized.contains("---"))
}

@Test func `normalize uses context aware file path shortening`() {
    let original = "Please read /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift."

    let normalized = TextForSpeech.Normalize.text(
        original,
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly",
        ),
    )

    #expect(normalized.contains("current directory Sources Speak Swiftly"))
    #expect(!normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
}

@Test func `normalize compacts repeated paths in the same directory`() {
    let original = """
    Compare /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift and /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/WorkerRuntime.swift.
    """

    let normalized = TextForSpeech.Normalize.text(
        original,
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly",
        ),
    )

    let sharedPrefix = "current directory Sources Speak Swiftly"
    #expect(occurrenceCount(of: sharedPrefix, in: normalized) == 1)
    #expect(normalized.contains("Speech Text Normalizer dot swift"))
    #expect(normalized.contains("same directory, Worker Runtime dot swift"))
}

@Test func `normalize compacts repeated exact paths`() {
    let original = """
    Read /tmp/Thing.swift, then read /tmp/Thing.swift again.
    """

    let normalized = TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("tmp Thing dot swift"))
    #expect(normalized.contains("same path"))
    #expect(occurrenceCount(of: "tmp Thing dot swift", in: normalized) == 1)
}

@Test func `normalize compacts repeated relative paths in the same directory`() {
    let original = """
    Compare ./Sources/WorkerRuntime.swift and ./Sources/ProfileStore.swift.
    """

    let normalized = TextForSpeech.Normalize.text(original, format: .plain)

    #expect(normalized.contains("current directory Sources Worker Runtime dot swift"))
    #expect(normalized.contains("same directory, Profile Store dot swift"))
    #expect(!normalized.contains("dot slash Sources"))
}

@Test func `normalize applies custom replacements around built ins`() {
    let profile = TextForSpeech.Profile(
        id: "custom",
        name: "Custom",
        replacements: [
            TextForSpeech.Replacement(
                "chrommmaticallly",
                with: "chromatically",
                during: .beforeBuiltIns,
            ),
            TextForSpeech.Replacement(
                "snake case stuff",
                with: "settings token",
                during: .afterBuiltIns,
                forTextFormats: [.plain],
            ),
        ],
    )

    let normalized = TextForSpeech.Normalize.text(
        "Please say chrommmaticallly and snake_case_stuff once.",
        customProfile: profile,
        format: .plain,
    )

    #expect(normalized.contains("chromatically"))
    #expect(normalized.contains("settings token"))
    #expect(!normalized.contains("c h r o m"))
    #expect(!normalized.contains("snake case stuff"))
}

@Test func `whole token custom replacements preserve punctuation boundaries`() {
    let profile = TextForSpeech.Profile(
        id: "custom-whole-token",
        name: "Custom Whole Token",
        replacements: [
            TextForSpeech.Replacement(
                "TODO",
                with: "to do marker",
                matching: .wholeToken,
            ),
        ],
    )

    let normalized = TextForSpeech.Normalize.text(
        "Keep (TODO), TODO, and TODO.",
        customProfile: profile,
        format: .plain,
    )

    #expect(normalized.contains("(to do marker),"))
    #expect(normalized.contains("to do marker,"))
    #expect(normalized.contains("to do marker."))
    #expect(!normalized.contains("TODO"))
}

@Test func `detect text format finds markdown`() {
    let markdown = """
    # Header

    Read `code` and [docs](https://example.com).
    """

    #expect(TextForSpeech.Normalize.detectTextFormat(in: markdown) == .markdown)
}

@Test func `detect text format finds list html cli and log inputs`() {
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

@Test func `context format overrides automatic detection`() {
    let text = """
    # Header

    - First
    - Second
    """

    let normalized = TextForSpeech.Normalize.text(
        text,
        context: TextForSpeech.Context(textFormat: .list),
    )

    #expect(normalized.contains("Header"))
}

@Test func `normalize text speaks markdown priority list labels`() {
    let original = """
    - [P1] Fix the crash
    - [P2] Add tests
    """

    let normalized = TextForSpeech.Normalize.text(
        original,
        format: .markdown,
    )

    #expect(normalized.contains("Priority Level One. Fix the crash"))
    #expect(normalized.contains("Priority Level Two. Add tests"))
    #expect(!normalized.contains("[P1]"))
}

@Test func `normalize text speaks plain priority list labels`() {
    let original = """
    [P4] Triage the next report
    [P5] Prepare the follow up
    """

    let normalized = TextForSpeech.Normalize.text(
        original,
        format: .plain,
    )

    #expect(normalized.contains("Priority Level Four. Triage the next report"))
    #expect(normalized.contains("Priority Level Five. Prepare the follow up"))
    #expect(!normalized.contains("[P4]"))
}

@Test func `normalize text uses nested format for embedded swift code`() {
    let original = """
    ```swift
    let sampleRate = profile?.sampleRate ?? 24000
    ```
    """

    let normalized = TextForSpeech.Normalize.text(
        original,
        format: .markdown,
        nestedFormat: .swift,
    )

    #expect(normalized.contains("Code sample."))
    #expect(normalized.contains("optional chaining"))
    #expect(normalized.contains("nil coalescing"))
}

@Test func `normalize text uses nested source format from context`() {
    let original = """
    ```swift
    let sampleRate = profile?.sampleRate ?? 24000
    ```
    """

    let normalized = TextForSpeech.Normalize.text(
        original,
        context: TextForSpeech.Context(
            textFormat: .markdown,
            nestedSourceFormat: .swift,
        ),
    )

    #expect(normalized.contains("optional chaining"))
    #expect(normalized.contains("nil coalescing"))
}

@Test func `inline code file paths use path speech instead of generic code speech`() {
    let normalized = TextForSpeech.Normalize.text(
        "Read `/Users/galew/Workspace/SpeakSwiftly/WorkerRuntime.swift` now.",
        format: .markdown,
    )

    #expect(normalized.contains("gale wumbo Workspace Speak Swiftly Worker Runtime dot swift"))
    #expect(!normalized.contains("gale wumbo slash Workspace"))
}

@Test func `inline code file paths keep context aware shortening`() {
    let normalized = TextForSpeech.Normalize.text(
        "Read `/Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/WorkerRuntime.swift` now.",
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly",
            textFormat: .markdown,
        ),
    )

    #expect(normalized.contains("current directory Sources Speak Swiftly Worker Runtime dot swift"))
    #expect(!normalized.contains("current directory slash"))
}

@Test func `inline code file references keep context aware shortening`() {
    let normalized = TextForSpeech.Normalize.text(
        "Read `/Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/WorkerRuntime.swift:12` now.",
        context: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly",
            textFormat: .markdown,
        ),
    )

    #expect(normalized.contains("current directory Sources Speak Swiftly Worker Runtime dot swift at line 12"))
    #expect(!normalized.contains("gale wumbo Workspace Speak Swiftly"))
}

@Test func `inline code relative file references use directory aware path speech`() {
    let normalized = TextForSpeech.Normalize.text(
        "Read `../Sources/WorkerRuntime.swift:12` now.",
        format: .markdown,
    )

    #expect(normalized.contains("parent directory Sources Worker Runtime dot swift at line 12"))
    #expect(!normalized.contains("dot dot slash Sources"))
}

@Test func `inline slash operators stay in code speech lane`() {
    let normalized = TextForSpeech.Normalize.text(
        "Read `a/b` once.",
        format: .markdown,
    )

    #expect(normalized.contains("a slash b"))
    #expect(!normalized.contains("same path"))
}

@Test func `normalize source provides explicit whole source lane`() {
    let source = """
    struct WorkerRuntime {
        let sampleRate: Int
    }
    """

    let normalized = TextForSpeech.Normalize.source(source, as: .swift)

    #expect(!normalized.contains("open brace"))
    #expect(normalized.contains("sample Rate"))
}

@Test func `normalize source accepts request context without changing output`() {
    let source = """
    struct WorkerRuntime {
        let sampleRate: Int
    }
    """

    let normalized = TextForSpeech.Normalize.source(
        source,
        as: .swift,
        requestContext: TextForSpeech.RequestContext(
            source: "codex",
            app: "SpeakSwiftly",
            topic: "normalization",
        ),
    )

    #expect(!normalized.contains("open brace"))
    #expect(normalized.contains("sample Rate"))
}

@Test func `compact style keeps whole source more visual and less spoken`() {
    let source = """
    struct WorkerRuntime {
        let sampleRate: Int
    }
    """

    let normalized = TextForSpeech.Normalize.source(
        source,
        as: .swift,
        style: .compact,
    )

    #expect(!normalized.contains("open brace"))
    #expect(normalized.contains("sample Rate"))
}

@Test func `styles differentiate function calls issue references flags and file refs`() {
    let original = "Run foo() with --help and see #123 in WorkerRuntime.swift:42:7."

    let compact = TextForSpeech.Normalize.text(
        original,
        style: .compact,
        format: .plain,
    )
    let balanced = TextForSpeech.Normalize.text(
        original,
        style: .balanced,
        format: .plain,
    )
    let explicit = TextForSpeech.Normalize.text(
        original,
        style: .explicit,
        format: .plain,
    )

    #expect(compact.contains("foo"))
    #expect(!compact.contains("function call"))
    #expect(compact.contains("help"))
    #expect(!compact.contains("double tack help"))
    #expect(compact.contains("123"))
    #expect(!compact.contains("issue 123"))

    #expect(balanced.contains("foo function"))
    #expect(balanced.contains("double tack help"))
    #expect(balanced.contains("issue 123"))
    #expect(balanced.contains("Worker Runtime dot swift line 42 column 7"))

    #expect(explicit.contains("foo function call"))
    #expect(explicit.contains("long flag help"))
    #expect(explicit.contains("issue number 123"))
    #expect(explicit.contains("file Worker Runtime dot swift line 42 column 7"))
}

@Test func `styles use at line for line only file references`() {
    let original = "See MarvisTTSModel.swift:208."

    let balanced = TextForSpeech.Normalize.text(
        original,
        style: .balanced,
        format: .plain,
    )
    let explicit = TextForSpeech.Normalize.text(
        original,
        style: .explicit,
        format: .plain,
    )

    #expect(balanced.contains("Marvis TTS Model dot swift at line 208"))
    #expect(explicit.contains("file Marvis TTS Model dot swift at line 208"))
}

@Test func `balanced style speaks short and long cli flag prefixes as tack words`() {
    let original = "Run codex --version and git branch -d."

    let normalized = TextForSpeech.Normalize.text(
        original,
        style: .balanced,
        format: .plain,
    )

    #expect(normalized.contains("codex double tack version"))
    #expect(normalized.contains("git branch tack d"))
    #expect(!normalized.contains("dash"))
}
