import Testing
@testable import TextForSpeech

// MARK: - Forensics

@Test func wordsTokenizeNaturalLanguageText() {
    let words = TextForSpeech.Forensics.words(
        in: "Please read /tmp/Thing and NSApplication.didFinishLaunchingNotification once."
    )

    #expect(words.contains("Please"))
    #expect(words.contains("read"))
    #expect(words.contains("Thing"))
    #expect(words.contains("and"))
    #expect(words.contains("once"))
}
