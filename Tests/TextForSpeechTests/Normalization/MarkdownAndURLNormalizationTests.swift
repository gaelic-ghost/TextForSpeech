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

@Test func `priority bullets become spoken levels`() {
    let text = """
    - [P1] Fix the crash
    - [P2] Add coverage
    """

    let normalized = TextNormalizer.normalizePriorityListItems(text)

    #expect(normalized.contains("Priority Level One. Fix the crash"))
    #expect(normalized.contains("Priority Level Two. Add coverage"))
    #expect(!normalized.contains("[P1]"))
    #expect(!normalized.contains("- [P2]"))
}

@Test func `priority numbered lists become spoken levels`() {
    let text = """
    1. [P3] Investigate logs
    2. [P12] Follow up later
    """

    let normalized = TextNormalizer.normalizePriorityListItems(text)

    #expect(normalized.contains("Priority Level Three. Investigate logs"))
    #expect(normalized.contains("Priority Level Twelve. Follow up later"))
    #expect(!normalized.contains("1. [P3]"))
}

@Test func `priority task lists become spoken levels`() {
    let text = """
    - [ ] [P1] Fix the crash
    - [x] [P2]: Add coverage
    """

    let normalized = TextNormalizer.normalizePriorityListItems(text)

    #expect(normalized.contains("Priority Level One. Fix the crash"))
    #expect(normalized.contains("Priority Level Two. Add coverage"))
    #expect(!normalized.contains("[ ] [P1]"))
    #expect(!normalized.contains("[x] [P2]:"))
}

@Test func `priority labels only rewrite at list item starts`() {
    let text = "We mentioned [P1] inline, not as a list item."

    let normalized = TextNormalizer.normalizePriorityListItems(text)

    #expect(normalized == text)
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

@Test func `urls omit mixed case leading WWW`() {
    let text = "Open https://WWW.Example.com/docs now."

    let normalized = TextNormalizer.normalizeURLs(text)

    #expect(normalized.contains("Example dot com slash docs"))
    #expect(!normalized.contains("WWW"))
}

@Test func `non HTTPUR ls keep their scheme`() {
    let text = "Open file://tmp/Thing now."

    let normalized = TextNormalizer.normalizeURLs(text)

    #expect(normalized.contains("file colon slash slash tmp slash Thing"))
}
