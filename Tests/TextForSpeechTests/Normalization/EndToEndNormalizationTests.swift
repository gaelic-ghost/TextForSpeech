import Testing
@testable import TextForSpeech

// MARK: - End-to-End Normalization

private func occurrenceCount(of needle: String, in haystack: String) -> Int {
    haystack.components(separatedBy: needle).count - 1
}

@Test func `normalize preserves mixed input behavior`() async throws {
    let original = """
    Please read /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift, NSApplication.didFinishLaunchingNotification, camelCaseStuff, snake_case_stuff, f32, cosF32, and `profile?.sampleRate ?? 24000`.
    """

    let normalized = try await TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("gale wumbo Workspace Speak Swiftly"))
    #expect(normalized.contains("NSApplication dot did Finish Launching Notification"))
    #expect(normalized.contains("camel Case Stuff"))
    #expect(normalized.contains("snake case stuff"))
    #expect(normalized.contains("float thirty two"))
    #expect(normalized.contains("cosine float thirty two"))
    #expect(normalized.contains("profile optional chaining sample Rate nil coalescing 24000"))
}

@Test func `normalize accepts request context without changing output`() async throws {
    let original = "Read /tmp/Thing.swift and `profile?.sampleRate ?? 24000`."

    let normalized = try await TextForSpeech.Normalize.text(
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

@Test func `normalize preserves markdown links code blocks and spiral words`() async throws {
    let original = """
    Read [the docs](https://example.com/docs) first.

    ```swift
    let sourcePath = "/tmp/Thing"
    ```

    Also say chrommmaticallly once.
    """

    let normalized = try await TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("the docs, link example dot com slash docs"))
    #expect(normalized.contains("Code sample."))
    #expect(normalized.contains("slash tmp slash Thing"))
    #expect(normalized.contains("c h r o m m m a t i c a l l l y"))
}

@Test func `normalize handles standalone urls before path passes`() async throws {
    let original = "Open https://example.com/docs/path_now before /tmp/Thing."

    let normalized = try await TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("example dot com slash docs slash path now"))
    #expect(normalized.contains("tmp Thing"))
}

@Test func `repeated underscores collapse to speech safe spacing`() async throws {
    let original = "Read snake___case and /tmp/path___now once."

    let normalized = try await TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("snake case"))
    #expect(normalized.contains("tmp path now"))
    #expect(!normalized.contains("underscore"))
    #expect(!normalized.contains("___"))
}

@Test func `repeated dashes collapse to speech safe spacing`() async throws {
    let original = "Read kebab---case and /tmp/path---now once."

    let normalized = try await TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("kebab case"))
    #expect(normalized.contains("tmp path now"))
    #expect(!normalized.contains("dash"))
    #expect(!normalized.contains("---"))
}

@Test func `normalize uses context aware file path shortening`() async throws {
    let original = "Please read /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift."

    let normalized = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly",
        ),
    )

    #expect(normalized.contains("current directory Sources Speak Swiftly"))
    #expect(!normalized.contains("gale wumbo slash Workspace slash Speak Swiftly"))
}

@Test func `normalize compacts repeated paths in the same directory`() async throws {
    let original = """
    Compare /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/SpeechTextNormalizer.swift and /Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/WorkerRuntime.swift.
    """

    let normalized = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly",
        ),
    )

    let sharedPrefix = "current directory Sources Speak Swiftly"
    #expect(occurrenceCount(of: sharedPrefix, in: normalized) == 1)
    #expect(normalized.contains("Speech Text Normalizer dot swift"))
    #expect(normalized.contains("same directory, Worker Runtime dot swift"))
}

@Test func `normalize compacts repeated exact paths`() async throws {
    let original = """
    Read /tmp/Thing.swift, then read /tmp/Thing.swift again.
    """

    let normalized = try await TextForSpeech.Normalize.text(original)

    #expect(normalized.contains("tmp Thing dot swift"))
    #expect(normalized.contains("same path"))
    #expect(occurrenceCount(of: "tmp Thing dot swift", in: normalized) == 1)
}

@Test func `normalize compacts repeated relative paths in the same directory`() async throws {
    let original = """
    Compare ./Sources/WorkerRuntime.swift and ./Sources/ProfileStore.swift.
    """

    let normalized = try await TextForSpeech.Normalize.text(original, withContext: TextForSpeech.Context(textFormat: .plain))

    #expect(normalized.contains("current directory Sources Worker Runtime dot swift"))
    #expect(normalized.contains("same directory, Profile Store dot swift"))
    #expect(!normalized.contains("dot slash Sources"))
}

@Test func `normalize applies custom replacements around built ins`() async throws {
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

    let normalized = try await TextForSpeech.Normalize.text(
        "Please say chrommmaticallly and snake_case_stuff once.",
        withContext: TextForSpeech.Context(textFormat: .plain),
        customProfile: profile,
    )

    #expect(normalized.contains("chromatically"))
    #expect(normalized.contains("settings token"))
    #expect(!normalized.contains("c h r o m"))
    #expect(!normalized.contains("snake case stuff"))
}

@Test func `whole token custom replacements preserve punctuation boundaries`() async throws {
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

    let normalized = try await TextForSpeech.Normalize.text(
        "Keep (TODO), TODO, and TODO.",
        withContext: TextForSpeech.Context(textFormat: .plain),
        customProfile: profile,
    )

    #expect(normalized.contains("(to do marker),"))
    #expect(normalized.contains("to do marker,"))
    #expect(normalized.contains("to do marker."))
    #expect(!normalized.contains("TODO"))
}

@Test func `normalize text preserves line breaks paragraphs and suffix punctuation`() async throws {
    let profile = TextForSpeech.Profile(
        id: "custom-structure",
        name: "Custom Structure",
        replacements: [
            TextForSpeech.Replacement(
                "TODO",
                with: "to do marker",
                matching: .wholeToken,
            ),
        ],
    )

    let normalized = try await TextForSpeech.Normalize.text(
        """
        Keep TODO,
        and camelCaseStuff.

        Close with WorkerRuntime.swift.
        """,
        withContext: TextForSpeech.Context(textFormat: .plain),
        customProfile: profile,
    )

    #expect(
        normalized
            ==
            """
            Keep to do marker,
            and camel Case Stuff.

            Close with Worker Runtime dot swift.
            """
    )
}

@Test func `normalize text preserves nine paragraph prose structure`() async throws {
    let normalized = try await TextForSpeech.Normalize.text(
        """
        First paragraph, with a comma after the opening phrase. It mentions camelCaseStuff and closes cleanly.

        Second paragraph keeps speaking in ordinary prose. It mentions WorkerRuntime.swift, then ends with a period.

        Third paragraph asks for calm structure, not flattening. It keeps every sentence where it started.

        Fourth paragraph says TODO should stay where it belongs, if replaced. It also keeps commas, periods, and spacing intact.

        Fifth paragraph brings in snake_case_stuff and kebab-case-stuff. Both should normalize without collapsing the paragraph break after them.

        Sixth paragraph mentions /tmp/Thing.swift in the middle of a sentence. The path should become speech-safe while the prose shape stays put.

        Seventh paragraph includes NSApplication.didFinishLaunchingNotification. The dotted identifier should change, but not the paragraph boundary.

        Eighth paragraph adds one more ordinary sentence, with another comma, to make the structure test harder. Nothing should be fused into its neighbors.

        Ninth paragraph closes the sample. If the formatter is still flattening prose, this test should catch it.
        """,
        withContext: TextForSpeech.Context(textFormat: .plain),
    )

    let paragraphs = normalized
        .components(separatedBy: "\n\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    #expect(paragraphs.count == 9)
    #expect(occurrenceCount(of: "\n\n", in: normalized) == 8)
    #expect(normalized.contains("First paragraph, with a comma"))
    #expect(normalized.contains("camel Case Stuff"))
    #expect(normalized.contains("Worker Runtime dot swift, then ends with a period."))
    #expect(normalized.contains("snake case stuff"))
    #expect(normalized.contains("kebab case stuff"))
    #expect(normalized.contains("tmp Thing dot swift"))
    #expect(normalized.contains("NSApplication dot did Finish Launching Notification"))
    #expect(!normalized.contains("First paragraph, with a comma after the opening phrase. It mentions camel Case Stuff and closes cleanly. Second paragraph"))
    #expect(!normalized.contains("neighbors. Ninth paragraph"))
}

@Test func `detect text format finds markdown`() async throws {
    let markdown = """
    # Header

    Read `code` and [docs](https://example.com).
    """

    #expect(TextForSpeech.Normalize.detectTextFormat(in: markdown) == .markdown)
}

@Test func `detect text format finds list html cli and log inputs`() async throws {
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

@Test func `context format overrides automatic detection`() async throws {
    let text = """
    # Header

    - First
    - Second
    """

    let normalized = try await TextForSpeech.Normalize.text(
        text,
        withContext: TextForSpeech.Context(textFormat: .list),
    )

    #expect(normalized.contains("Header"))
}

@Test func `normalize text speaks markdown priority list labels`() async throws {
    let original = """
    - [P1] Fix the crash
    - [P2] Add tests
    """

    let normalized = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(textFormat: .markdown),
    )

    #expect(normalized.contains("Priority Level One. Fix the crash"))
    #expect(normalized.contains("Priority Level Two. Add tests"))
    #expect(!normalized.contains("[P1]"))
}

@Test func `normalize text speaks plain priority list labels`() async throws {
    let original = """
    [P4] Triage the next report
    [P5] Prepare the follow up
    """

    let normalized = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(textFormat: .plain),
    )

    #expect(normalized.contains("Priority Level Four. Triage the next report"))
    #expect(normalized.contains("Priority Level Five. Prepare the follow up"))
    #expect(!normalized.contains("[P4]"))
}

@Test func `normalize text uses nested format for embedded swift code`() async throws {
    let original = """
    ```swift
    let sampleRate = profile?.sampleRate ?? 24000
    ```
    """

    let normalized = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(
            textFormat: .markdown,
            nestedSourceFormat: .swift,
        ),
    )

    #expect(normalized.contains("Code sample."))
    #expect(normalized.contains("optional chaining"))
    #expect(normalized.contains("nil coalescing"))
}

@Test func `normalize text uses nested source format from context`() async throws {
    let original = """
    ```swift
    let sampleRate = profile?.sampleRate ?? 24000
    ```
    """

    let normalized = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(
            textFormat: .markdown,
            nestedSourceFormat: .swift,
        ),
    )

    #expect(normalized.contains("optional chaining"))
    #expect(normalized.contains("nil coalescing"))
}

@Test func `inline code file paths use path speech instead of generic code speech`() async throws {
    let normalized = try await TextForSpeech.Normalize.text(
        "Read `/Users/galew/Workspace/SpeakSwiftly/WorkerRuntime.swift` now.",
        withContext: TextForSpeech.Context(textFormat: .markdown),
    )

    #expect(normalized.contains("gale wumbo Workspace Speak Swiftly Worker Runtime dot swift"))
    #expect(!normalized.contains("gale wumbo slash Workspace"))
}

@Test func `inline code file paths keep context aware shortening`() async throws {
    let normalized = try await TextForSpeech.Normalize.text(
        "Read `/Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/WorkerRuntime.swift` now.",
        withContext: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly",
            textFormat: .markdown,
        ),
    )

    #expect(normalized.contains("current directory Sources Speak Swiftly Worker Runtime dot swift"))
    #expect(!normalized.contains("current directory slash"))
}

@Test func `inline code file references keep context aware shortening`() async throws {
    let normalized = try await TextForSpeech.Normalize.text(
        "Read `/Users/galew/Workspace/SpeakSwiftly/Sources/SpeakSwiftly/WorkerRuntime.swift:12` now.",
        withContext: TextForSpeech.Context(
            cwd: "/Users/galew/Workspace/SpeakSwiftly",
            repoRoot: "/Users/galew/Workspace/SpeakSwiftly",
            textFormat: .markdown,
        ),
    )

    #expect(normalized.contains("current directory Sources Speak Swiftly Worker Runtime dot swift at line 12"))
    #expect(!normalized.contains("gale wumbo Workspace Speak Swiftly"))
}

@Test func `inline code relative file references use directory aware path speech`() async throws {
    let normalized = try await TextForSpeech.Normalize.text(
        "Read `../Sources/WorkerRuntime.swift:12` now.",
        withContext: TextForSpeech.Context(textFormat: .markdown),
    )

    #expect(normalized.contains("parent directory Sources Worker Runtime dot swift at line 12"))
    #expect(!normalized.contains("dot dot slash Sources"))
}

@Test func `inline slash operators stay in code speech lane`() async throws {
    let normalized = try await TextForSpeech.Normalize.text(
        "Read `a/b` once.",
        withContext: TextForSpeech.Context(textFormat: .markdown),
    )

    #expect(normalized.contains("a slash b"))
    #expect(!normalized.contains("same path"))
}

@Test func `normalize source provides explicit whole source lane`() async throws {
    let source = """
    struct WorkerRuntime {
        let sampleRate: Int
    }
    """

    let normalized = try await TextForSpeech.Normalize.source(source, as: .swift)

    #expect(!normalized.contains("open brace"))
    #expect(normalized.contains("sample Rate"))
}

@Test func `normalize source preserves line and paragraph breaks`() async throws {
    let source = """
    struct WorkerRuntime {
        let sampleRate: Int

        let fallbackValue: Int
    }
    """

    let normalized = try await TextForSpeech.Normalize.source(source, as: .swift)

    #expect(normalized.split(separator: "\n", omittingEmptySubsequences: false).count == 5)
    #expect(normalized.contains("\n\n"))
    #expect(normalized.contains("sample Rate"))
    #expect(normalized.contains("fallback Value"))
}

@Test func `normalize source accepts request context without changing output`() async throws {
    let source = """
    struct WorkerRuntime {
        let sampleRate: Int
    }
    """

    let normalized = try await TextForSpeech.Normalize.source(
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

@Test func `compact style keeps whole source more visual and less spoken`() async throws {
    let source = """
    struct WorkerRuntime {
        let sampleRate: Int
    }
    """

    let normalized = try await TextForSpeech.Normalize.source(
        source,
        as: .swift,
        style: .compact,
    )

    #expect(!normalized.contains("open brace"))
    #expect(normalized.contains("sample Rate"))
}

@Test func `malformed source delimiters stay audible`() async throws {
    let normalized = try await TextForSpeech.Normalize.source(
        "let x = ([)]",
        as: .swift,
    )

    #expect(normalized.contains("open parenthesis"))
    #expect(normalized.contains("open bracket"))
    #expect(normalized.contains("close parenthesis"))
    #expect(normalized.contains("close bracket"))
}

@Test func `styles differentiate function calls issue references flags and file refs`() async throws {
    let original = "Run foo() with --help and see #123 in WorkerRuntime.swift:42:7."

    let compact = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(textFormat: .plain),
        style: .compact,
    )
    let balanced = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(textFormat: .plain),
        style: .balanced,
    )
    let explicit = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(textFormat: .plain),
        style: .explicit,
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

@Test func `double colon stays silent except in explicit style`() async throws {
    let original = "let value = Thing::value"

    let compact = try await TextForSpeech.Normalize.source(
        original,
        as: .swift,
        style: .compact,
    )
    let balanced = try await TextForSpeech.Normalize.source(
        original,
        as: .swift,
        style: .balanced,
    )
    let explicit = try await TextForSpeech.Normalize.source(
        original,
        as: .swift,
        style: .explicit,
    )

    #expect(compact.contains("Thing value"))
    #expect(!compact.contains("::"))
    #expect(!compact.contains("double colon"))

    #expect(balanced.contains("Thing value"))
    #expect(!balanced.contains("::"))
    #expect(!balanced.contains("double colon"))

    #expect(explicit.contains("Thing double colon value"))
}

@Test func `styles use at line for line only file references`() async throws {
    let original = "See MarvisTTSModel.swift:208."

    let balanced = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(textFormat: .plain),
        style: .balanced,
    )
    let explicit = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(textFormat: .plain),
        style: .explicit,
    )

    #expect(balanced.contains("Marvis TTS Model dot swift at line 208"))
    #expect(explicit.contains("file Marvis TTS Model dot swift at line 208"))
}

@Test func `balanced style speaks short and long cli flag prefixes as tack words`() async throws {
    let original = "Run codex --version and git branch -d."

    let normalized = try await TextForSpeech.Normalize.text(
        original,
        withContext: TextForSpeech.Context(textFormat: .plain),
        style: .balanced,
    )

    #expect(normalized.contains("codex double tack version"))
    #expect(normalized.contains("git branch tack d"))
    #expect(!normalized.contains("dash"))
}
