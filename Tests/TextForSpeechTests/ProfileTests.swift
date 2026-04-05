import Testing
@testable import TextForSpeech

// MARK: - Profiles

@Test func profileFiltersReplacementsByPhaseAndFormat() {
    let profile = TextForSpeech.Profile(
        replacements: [
            TextForSpeech.Replacement(
                "Thing",
                with: "Swift thing",
                id: "swift",
                in: .beforeNormalization,
                for: [.swift]
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Any source thing",
                id: "source",
                in: .beforeNormalization,
                for: [.source],
                priority: 10
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Final thing",
                id: "final",
                in: .afterNormalization
            ),
        ]
    )

    let beforeNormalization = profile.replacements(for: .beforeNormalization, in: .swift)
    let afterNormalization = profile.replacements(for: .afterNormalization, in: .swift)

    #expect(beforeNormalization.map(\.id) == ["source", "swift"])
    #expect(afterNormalization.map(\.id) == ["final"])
}

@Test func baseProfileAndDefaultProfileStayDistinct() {
    #expect(TextForSpeech.Profile.base.id == "base")
    #expect(TextForSpeech.Profile.default.id == "default")
    #expect(TextForSpeech.Profile.base.name == "Base")
    #expect(TextForSpeech.Profile.default.name == "Default")
}
