// MARK: - Built-in Profiles

public extension TextForSpeech.Profile {
    static let base = TextForSpeech.Profile(
        id: "base",
        name: "Base",
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
            TextForSpeech.Replacement(
                id: "base-repeated-letter-run",
                matching: .token(.repeatedLetterRun),
                using: .spellOut,
                priority: -100
            ),
        ]
    )

    static let `default` = TextForSpeech.Profile()
}
