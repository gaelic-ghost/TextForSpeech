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
                during: .beforeBuiltIns,
                forTextFormats: [],
                forSourceFormats: [.swift]
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Any source thing",
                id: "source",
                during: .beforeBuiltIns,
                forTextFormats: [],
                forSourceFormats: [.generic],
                priority: 10
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Final thing",
                id: "final",
                during: .afterBuiltIns
            ),
        ]
    )

    let beforeBuiltIns = profile.replacements(
        for: TextForSpeech.Replacement.Phase.beforeBuiltIns,
        in: TextForSpeech.SourceFormat.swift
    )
    let afterBuiltIns = profile.replacements(
        for: TextForSpeech.Replacement.Phase.afterBuiltIns,
        in: TextForSpeech.SourceFormat.swift
    )

    #expect(beforeBuiltIns.map(\.id) == ["source", "swift"])
    #expect(afterBuiltIns.map(\.id) == ["final"])
}

@Test func profileFiltersTextScopedReplacementsIndependentlyFromSourceScopedOnes() {
    let profile = TextForSpeech.Profile(
        replacements: [
            TextForSpeech.Replacement(
                "Thing",
                with: "Markdown thing",
                id: "markdown",
                during: .beforeBuiltIns,
                forTextFormats: [.markdown]
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Swift thing",
                id: "swift",
                during: .beforeBuiltIns,
                forTextFormats: [],
                forSourceFormats: [.swift]
            ),
        ]
    )

    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeBuiltIns,
            in: TextForSpeech.TextFormat.markdown
        ).map(\.id) == ["markdown"]
    )
    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeBuiltIns,
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
                during: .beforeBuiltIns,
                forTextFormats: [],
                forSourceFormats: [.generic]
            )
        ]
    )

    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeBuiltIns,
            in: TextForSpeech.SourceFormat.swift
        ).map(\.id) == ["source"]
    )
    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeBuiltIns,
            in: TextForSpeech.SourceFormat.python
        ).map(\.id) == ["source"]
    )
}

@Test func defaultProfileStartsEmpty() {
    #expect(TextForSpeech.Profile.default.id == "default")
    #expect(TextForSpeech.Profile.default.name == "Default")
    #expect(TextForSpeech.Profile.default.replacements.isEmpty)
}
