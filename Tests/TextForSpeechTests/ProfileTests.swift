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
                for: [],
                sourceFormats: [.swift]
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Any source thing",
                id: "source",
                in: .beforeNormalization,
                for: [],
                sourceFormats: [.generic],
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

    let beforeNormalization = profile.replacements(
        for: TextForSpeech.Replacement.Phase.beforeNormalization,
        in: TextForSpeech.SourceFormat.swift
    )
    let afterNormalization = profile.replacements(
        for: TextForSpeech.Replacement.Phase.afterNormalization,
        in: TextForSpeech.SourceFormat.swift
    )

    #expect(beforeNormalization.map(\.id) == ["source", "swift"])
    #expect(afterNormalization.map(\.id) == ["final"])
}

@Test func profileFiltersTextScopedReplacementsIndependentlyFromSourceScopedOnes() {
    let profile = TextForSpeech.Profile(
        replacements: [
            TextForSpeech.Replacement(
                "Thing",
                with: "Markdown thing",
                id: "markdown",
                in: .beforeNormalization,
                for: [.markdown]
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Swift thing",
                id: "swift",
                in: .beforeNormalization,
                for: [],
                sourceFormats: [.swift]
            ),
        ]
    )

    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeNormalization,
            in: TextForSpeech.TextFormat.markdown
        ).map(\.id) == ["markdown"]
    )
    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeNormalization,
            in: TextForSpeech.SourceFormat.swift
        ).map(\.id) == ["swift"]
    )
}

@Test func genericSourceScopedReplacementsApplyToSpecificSourceFormats() {
    let profile = TextForSpeech.Profile(
        replacements: [
            TextForSpeech.Replacement(
                "Thing",
                with: "Any source thing",
                id: "source",
                in: .beforeNormalization,
                for: [],
                sourceFormats: [.generic]
            )
        ]
    )

    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeNormalization,
            in: TextForSpeech.SourceFormat.swift
        ).map(\.id) == ["source"]
    )
    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeNormalization,
            in: TextForSpeech.SourceFormat.python
        ).map(\.id) == ["source"]
    )
}

@Test func baseProfileAndDefaultProfileStayDistinct() {
    #expect(TextForSpeech.Profile.base.id == "base")
    #expect(TextForSpeech.Profile.default.id == "default")
    #expect(TextForSpeech.Profile.base.name == "Base")
    #expect(TextForSpeech.Profile.default.name == "Default")
}
