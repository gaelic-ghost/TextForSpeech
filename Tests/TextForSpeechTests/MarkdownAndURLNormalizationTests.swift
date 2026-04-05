import Testing
@testable import TextForSpeech

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
