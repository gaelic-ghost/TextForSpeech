import Testing
@testable import TextForSpeech

// MARK: - Parsing Utilities

@Test func `inline code bodies returns only closed spans`() {
    let bodies = TextNormalizer.inlineCodeBodies(
        in: "Read `profile?.sampleRate` then ignore `unterminated",
    )

    #expect(bodies == ["profile?.sampleRate"])
}

@Test func `inline code bodies keeps multiple closed spans in order`() {
    let bodies = TextNormalizer.inlineCodeBodies(
        in: "Read `stderr` and `stdout` before `WorkerRuntime.swift`.",
    )

    #expect(bodies == ["stderr", "stdout", "WorkerRuntime.swift"])
}

@Test func `markdown links skips malformed bracket and destination shapes`() {
    let links = TextNormalizer.markdownLinks(
        in: "Broken [label only] and [missing destination]( before [docs](https://example.com/docs).",
    )

    #expect(links.map(\.label) == ["docs"])
    #expect(links.map(\.destination) == ["https://example.com/docs"])
}

@Test func `markdown links returns multiple links with source ranges`() {
    let text = "Read [docs](https://example.com/docs) and [repo](https://github.com/example/repo)."
    let links = TextNormalizer.markdownLinks(in: text)

    #expect(links.map(\.label) == ["docs", "repo"])
    #expect(links.map(\.destination) == ["https://example.com/docs", "https://github.com/example/repo"])
    #expect(links.map { String(text[$0.fullRange]) } == [
        "[docs](https://example.com/docs)",
        "[repo](https://github.com/example/repo)",
    ])
}

@Test func `markdown header title trims hash markers and whitespace`() {
    #expect(TextNormalizer.markdownHeaderTitle(in: "  ## Release Notes  ") == "Release Notes")
    #expect(TextNormalizer.markdownHeaderTitle(in: "#") == nil)
    #expect(TextNormalizer.markdownHeaderTitle(in: "plain text") == nil)
}

@Test func `natural language words returns word tokens without punctuation`() {
    let words = TextNormalizer.naturalLanguageWords(in: "Hello, Gale. Ship v0.18.9!")

    #expect(words.contains("Hello"))
    #expect(words.contains("Gale"))
    #expect(words.contains("Ship"))
    #expect(!words.contains(","))
    #expect(!words.contains("!"))
}
