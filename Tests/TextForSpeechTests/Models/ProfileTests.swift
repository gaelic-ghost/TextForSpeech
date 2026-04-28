import Foundation
import Testing
@testable import TextForSpeech

// MARK: - Profiles

@Test func `profile filters replacements by phase and format`() {
    let profile = TextForSpeech.Profile(
        replacements: [
            TextForSpeech.Replacement(
                "Thing",
                with: "Swift thing",
                id: "swift",
                during: .beforeBuiltIns,
                forTextFormats: [],
                forSourceFormats: [.swift],
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Any source thing",
                id: "source",
                during: .beforeBuiltIns,
                forTextFormats: [],
                forSourceFormats: [.generic],
                priority: 10,
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Final thing",
                id: "final",
                during: .afterBuiltIns,
            ),
        ],
    )

    let beforeBuiltIns = profile.replacements(
        for: TextForSpeech.Replacement.Phase.beforeBuiltIns,
        in: TextForSpeech.SourceFormat.swift,
    )
    let afterBuiltIns = profile.replacements(
        for: TextForSpeech.Replacement.Phase.afterBuiltIns,
        in: TextForSpeech.SourceFormat.swift,
    )

    #expect(beforeBuiltIns.map(\.id) == ["source", "swift"])
    #expect(afterBuiltIns.map(\.id) == ["final"])
}

@Test func `profile filters text scoped replacements independently from source scoped ones`() {
    let profile = TextForSpeech.Profile(
        replacements: [
            TextForSpeech.Replacement(
                "Thing",
                with: "Markdown thing",
                id: "markdown",
                during: .beforeBuiltIns,
                forTextFormats: [.markdown],
            ),
            TextForSpeech.Replacement(
                "Thing",
                with: "Swift thing",
                id: "swift",
                during: .beforeBuiltIns,
                forTextFormats: [],
                forSourceFormats: [.swift],
            ),
        ],
    )

    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeBuiltIns,
            in: TextForSpeech.TextFormat.markdown,
        )
        .map(\.id) == ["markdown"],
    )
    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeBuiltIns,
            in: TextForSpeech.SourceFormat.swift,
        )
        .map(\.id) == ["swift"],
    )
}

@Test func `generic source scoped replacements apply to specific source formats`() {
    let profile = TextForSpeech.Profile(
        replacements: [
            TextForSpeech.Replacement(
                "Thing",
                with: "Any source thing",
                id: "source",
                during: .beforeBuiltIns,
                forTextFormats: [],
                forSourceFormats: [.generic],
            ),
        ],
    )

    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeBuiltIns,
            in: TextForSpeech.SourceFormat.swift,
        )
        .map(\.id) == ["source"],
    )
    #expect(
        profile.replacements(
            for: TextForSpeech.Replacement.Phase.beforeBuiltIns,
            in: TextForSpeech.SourceFormat.python,
        )
        .map(\.id) == ["source"],
    )
}

@Test func `default profile starts empty`() {
    #expect(TextForSpeech.Profile.default.id == "default")
    #expect(TextForSpeech.Profile.default.name == "Default")
    #expect(TextForSpeech.Profile.default.replacements.isEmpty)
}

@Test func `balanced base composes semantic core and balanced style`() {
    let balanced = TextForSpeech.Profile.builtInBase(style: .balanced)

    #expect(TextForSpeech.Profile.base == balanced)
    #expect(balanced.replacements.contains(where: { $0.id == "base-url" }))
    #expect(balanced.replacements.contains(where: { $0.id == "base-text-code-line" }))
}

@Test func `semantic core composes semantic role fragments`() {
    let semanticCore = TextForSpeech.Profile.semanticCore

    #expect(semanticCore.replacements.contains(where: { $0.id == "base-galew" }))
    #expect(semanticCore.replacements.contains(where: { $0.id == "base-f32" }))
    #expect(semanticCore.replacements.contains(where: { $0.id == "base-xcodeproj-extension" }))
    #expect(semanticCore.replacements.contains(where: { $0.id == "base-url" }))
    #expect(semanticCore.replacements.contains(where: { $0.id == "base-currency-amount" }))
    #expect(semanticCore.replacements.contains(where: { $0.id == "base-measured-value" }))
}

@Test func `built in style lookup returns named preset profiles`() {
    #expect(TextForSpeech.Profile.builtInStyle(.balanced).id == "base")
    #expect(TextForSpeech.Profile.builtInStyle(.compact).id == "compact-built-in-style")
    #expect(TextForSpeech.Profile.builtInStyle(.explicit).id == "explicit-built-in-style")
}

@Test func `request context decodes missing attributes as empty dictionary`() throws {
    let json = """
    {
      "source": "codex",
      "app": "SpeakSwiftly",
      "project": "TextForSpeech"
    }
    """
    let data = Data(json.utf8)

    let decoded = try JSONDecoder().decode(TextForSpeech.RequestContext.self, from: data)

    #expect(decoded.source == "codex")
    #expect(decoded.app == "SpeakSwiftly")
    #expect(decoded.project == "TextForSpeech")
    #expect(decoded.attributes.isEmpty)
}

@Test func `compact style drops balanced code line rules but keeps semantic core`() {
    let compact = TextForSpeech.Profile.builtInBase(style: .compact)

    #expect(compact.replacements.contains(where: { $0.id == "base-url" }))
    #expect(compact.replacements.contains(where: { $0.id == "compact-function-call" }))
    #expect(!compact.replacements.contains(where: { $0.id == "base-text-code-line" }))
    #expect(!compact.replacements.contains(where: { $0.id == "base-source-line" }))
}

@Test func `explicit style carries its own style specific rules`() {
    let explicit = TextForSpeech.Profile.builtInBase(style: .explicit)

    #expect(explicit.replacements.contains(where: { $0.id == "explicit-function-call" }))
    #expect(explicit.replacements.contains(where: { $0.id == "explicit-cli-flag" }))
    #expect(explicit.replacements.contains(where: { $0.id == "base-text-code-line" }))
}
