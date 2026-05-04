import Testing
@testable import TextForSpeech

@Test func `semantic attributed string marks data detector and developer token runs`() {
    let runs = TextNormalizer.semanticTokenRuns(
        in: "Open https://example.com, email mail@example.com, and Sources/App.swift:42 with sampleRate.",
    )

    #expect(
        runs.contains {
            $0.text == "https://example.com" && $0.kind == .link
        },
    )
    #expect(
        runs.contains {
            $0.text == "mail@example.com" && $0.kind == .emailAddress
        },
    )
    #expect(
        runs.contains {
            $0.text == "Sources/App.swift:42" && $0.kind == .fileLineReference
        },
    )
    #expect(
        runs.contains {
            $0.text == "sampleRate" && $0.kind == .camelCaseIdentifier
        },
    )
}

@Test func `semantic runs preserve plain text gaps around detected tokens`() {
    let runs = TextNormalizer.semanticRuns(in: "Use --verbose with buildProject().")

    #expect(
        runs.contains {
            $0.text == "--verbose" && $0.kind == .cliFlag
        },
    )
    #expect(
        runs.contains {
            $0.text == "buildProject()" && $0.kind == .functionCall
        },
    )
    #expect(runs.contains { $0.text.contains("Use ") && $0.kind == nil })
}

@Test func `semantic link runs normalize links without rewriting email addresses`() {
    let normalized = TextNormalizer.normalizeSemanticLinkRuns(
        "Open www.example.com and mail@example.com.",
    )

    #expect(normalized.contains("example dot com"))
    #expect(!normalized.contains("www"))
    #expect(normalized.contains("mail@example.com"))
}
