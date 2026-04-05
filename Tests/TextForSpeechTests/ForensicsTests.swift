import Testing
@testable import TextForSpeech

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
