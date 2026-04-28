extension TextForSpeech.Profile {
    /// Always-on token transforms for URLs, file paths, identifiers, and
    /// repeated-letter runs after literal semantic aliases have been applied.
    static let semanticTokenTransformReplacements: [TextForSpeech.Replacement] = [
        TextForSpeech.Replacement(
            id: "base-url",
            matching: .token(.url),
            using: .spokenURL,
            priority: -20,
        ),
        TextForSpeech.Replacement(
            id: "base-file-path",
            matching: .token(.filePath),
            using: .spokenPath,
            priority: -30,
        ),
        TextForSpeech.Replacement(
            id: "base-currency-amount",
            matching: .token(.currencyAmount),
            using: .spokenCurrencyAmount,
            priority: -35,
        ),
        TextForSpeech.Replacement(
            id: "base-measured-value",
            matching: .token(.measuredValue),
            using: .spokenMeasuredValue,
            priority: -37,
        ),
        TextForSpeech.Replacement(
            id: "base-dotted-identifier",
            matching: .token(.dottedIdentifier),
            using: .spokenIdentifier,
            priority: -40,
        ),
        TextForSpeech.Replacement(
            id: "base-snake-identifier",
            matching: .token(.snakeCaseIdentifier),
            using: .spokenIdentifier,
            priority: -50,
        ),
        TextForSpeech.Replacement(
            id: "base-dashed-identifier",
            matching: .token(.dashedIdentifier),
            using: .spokenIdentifier,
            priority: -60,
        ),
        TextForSpeech.Replacement(
            id: "base-camel-identifier",
            matching: .token(.camelCaseIdentifier),
            using: .spokenIdentifier,
            priority: -70,
        ),
        TextForSpeech.Replacement(
            id: "base-repeated-letter-run",
            matching: .token(.repeatedLetterRun),
            using: .spellOut,
            priority: -100,
        ),
    ]
}
