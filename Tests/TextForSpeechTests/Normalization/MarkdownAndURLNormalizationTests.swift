import Testing
@testable import TextForSpeech

// MARK: - Markdown and URL Handling

@Test func `fenced code blocks become spoken code samples`() {
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

@Test func `inline code spans become speakable`() {
    let text = "Read `profile?.sampleRate ?? 24000` once."

    let normalized = TextNormalizer.normalizeInlineCodeSpans(text)

    #expect(!normalized.contains("`"))
    #expect(normalized.contains("profile optional chaining sample Rate nil coalescing 24000"))
}

@Test func `inline file path spans do not fall back to spoken slash code`() {
    let text = "Read `/tmp/Thing.swift` once."

    let normalized = TextNormalizer.normalizeInlineCodeSpans(text)

    #expect(normalized.contains("tmp Thing dot swift"))
    #expect(!normalized.contains("tmp slash Thing"))
}

@Test func `slash operators inside inline code stay code shaped`() {
    let text = "Read `a/b` once."

    let normalized = TextNormalizer.normalizeInlineCodeSpans(text)

    #expect(normalized.contains("a slash b"))
    #expect(!normalized.contains("same path"))
}

@Test func `markdown links preserve label and destination`() {
    let text = "Open [the docs](https://example.com/docs) now."

    let normalized = TextNormalizer.normalizeMarkdownLinks(text)

    #expect(normalized.contains("the docs, link https://example.com/docs"))
}

@Test func `urls become spoken urls`() {
    let text = "Open https://example.com/docs now."

    let normalized = TextNormalizer.normalizeURLs(text)

    #expect(normalized.contains("example dot com slash docs"))
    #expect(!normalized.contains("https"))
}

@Test func `urls omit leading WWW`() {
    let text = "Open https://www.example.com/docs now."

    let normalized = TextNormalizer.normalizeURLs(text)

    #expect(normalized.contains("example dot com slash docs"))
    #expect(!normalized.contains("www"))
}

@Test func `non HTTPUR ls keep their scheme`() {
    let text = "Open file://tmp/Thing now."

    let normalized = TextNormalizer.normalizeURLs(text)

    #expect(normalized.contains("file colon slash slash tmp slash Thing"))
}
