// MARK: - Built-in Profiles

public extension TextForSpeech.Profile {
    static let semanticCore = TextForSpeech.Profile(
        id: "semantic-core",
        name: "Semantic Core",
        replacements: [
            TextForSpeech.Replacement(
                "galew",
                with: "gale wumbo",
                id: "base-galew",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                "galem",
                with: "gale mini",
                id: "base-galem",
                matching: .wholeToken,
                priority: -10
            ),
            TextForSpeech.Replacement(
                id: "base-url",
                matching: .token(.url),
                using: .spokenURL,
                priority: -20
            ),
            TextForSpeech.Replacement(
                id: "base-file-path",
                matching: .token(.filePath),
                using: .spokenPath,
                priority: -30
            ),
            TextForSpeech.Replacement(
                id: "base-dotted-identifier",
                matching: .token(.dottedIdentifier),
                using: .spokenIdentifier,
                priority: -40
            ),
            TextForSpeech.Replacement(
                id: "base-snake-identifier",
                matching: .token(.snakeCaseIdentifier),
                using: .spokenIdentifier,
                priority: -50
            ),
            TextForSpeech.Replacement(
                id: "base-dashed-identifier",
                matching: .token(.dashedIdentifier),
                using: .spokenIdentifier,
                priority: -60
            ),
            TextForSpeech.Replacement(
                id: "base-camel-identifier",
                matching: .token(.camelCaseIdentifier),
                using: .spokenIdentifier,
                priority: -70
            ),
            TextForSpeech.Replacement(
                id: "base-repeated-letter-run",
                matching: .token(.repeatedLetterRun),
                using: .spellOut,
                priority: -100
            ),
        ]
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

    static let base = builtInBase(style: .balanced)

    private static let balancedBuiltInStyle = TextForSpeech.Profile(
        id: "base",
        name: "Balanced Built-In Style",
        replacements: [
            TextForSpeech.Replacement(
                id: "base-text-code-line",
                matching: .line(.codeLike),
                using: .spokenCode,
                forTextFormats: Set(TextForSpeech.TextFormat.allCases),
                priority: -80
            ),
            TextForSpeech.Replacement(
                id: "base-source-line",
                matching: .line(.nonEmpty),
                using: .spokenCode,
                forSourceFormats: [.generic],
                priority: -90
            ),
        ]
    )

    private static let compactBuiltInStyle = TextForSpeech.Profile(
        id: "compact-built-in-style",
        name: "Compact Built-In Style",
        replacements: []
    )

    private static let explicitBuiltInStyle = TextForSpeech.Profile(
        id: "explicit-built-in-style",
        name: "Explicit Built-In Style",
        replacements: balancedBuiltInStyle.replacements
    )

    static let `default` = TextForSpeech.Profile()
}
