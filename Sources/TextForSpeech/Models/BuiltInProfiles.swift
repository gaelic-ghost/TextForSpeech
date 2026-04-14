// MARK: - Built-In Profiles

public extension TextForSpeech.Profile {
    /// The always-on shipped semantic layer composed from the semantic-role
    /// fragments in `Models/BuiltInProfiles/`.
    static let semanticCore = TextForSpeech.Profile(
        id: "semantic-core",
        name: "Semantic Core",
        replacements:
            semanticAliasReplacements
            + scalarPronunciationReplacements
            + extensionAliasReplacements
            + semanticTokenTransformReplacements
    )

    static func builtInStyle(_ style: TextForSpeech.BuiltInProfileStyle) -> TextForSpeech.Profile {
        switch style {
        case .balanced:
            balancedBuiltInStyle
        case .compact:
            compactBuiltInStyle
        case .explicit:
            explicitBuiltInStyle
        }
    }

    static func builtInBase(
        style: TextForSpeech.BuiltInProfileStyle
    ) -> TextForSpeech.Profile {
        semanticCore.merged(with: builtInStyle(style))
    }

    /// The default built-in base, equivalent to `builtInBase(style: .balanced)`.
    static let base = builtInBase(style: .balanced)
    static let `default` = TextForSpeech.Profile()
}
