// MARK: - Built-In Semantic Aliases

public extension TextForSpeech.Profile {
    /// Always-on semantic aliases for stable names that should be rewritten
    /// before any broader token transforms run.
    static let semanticAliasReplacements: [TextForSpeech.Replacement] = [
        TextForSpeech.Replacement(
            "galew",
            with: "gale wumbo",
            id: "base-galew",
            matching: .wholeToken,
            priority: -10,
        ),
        TextForSpeech.Replacement(
            "galem",
            with: "gale mini",
            id: "base-galem",
            matching: .wholeToken,
            priority: -10,
        ),
    ]
}
