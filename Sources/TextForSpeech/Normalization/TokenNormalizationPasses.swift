import Foundation

// MARK: - Token Normalization Passes

extension TextNormalizer {
    // MARK: Source Line Normalization

    static func normalizeStructuredSourceLines(
        _ text: String,
        format: TextForSpeech.SourceFormat,
    ) -> String {
        applySingleBaseRule(
            id: "base-source-line",
            to: text,
            format: .source(format),
        )
    }

    // MARK: Token-Level Passes

    static func normalizeURLs(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-url",
            to: text,
            format: .text(.plain),
        )
    }

    static func normalizeStandaloneGaleAliases(_ text: String) -> String {
        applyReplacementRules(
            text,
            profile: TextForSpeech.Profile(
                id: "base-aliases-only",
                name: "Base Aliases Only",
                replacements: [
                    TextForSpeech.Profile.base.replacement(id: "base-galew"),
                    TextForSpeech.Profile.base.replacement(id: "base-galem"),
                ].compactMap { $0 },
            ),
            format: .text(.plain),
            phase: .beforeBuiltIns,
        )
    }

    static func normalizeFilePaths(
        _ text: String,
        context: TextForSpeech.Context? = nil,
        profile _: TextForSpeech.Profile = .default,
        format _: NormalizationFormat = .text(.plain),
        nestedFormat _: TextForSpeech.SourceFormat? = nil,
    ) -> String {
        applySingleBaseRule(
            id: "base-file-path",
            to: text,
            format: .text(.plain),
            context: context,
        )
    }

    static func normalizeDottedIdentifiers(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-dotted-identifier",
            to: text,
            format: .text(.plain),
        )
    }

    static func normalizeSnakeCaseIdentifiers(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-snake-identifier",
            to: text,
            format: .text(.plain),
        )
    }

    static func normalizeDashedIdentifiers(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-dashed-identifier",
            to: text,
            format: .text(.plain),
        )
    }

    static func normalizeCamelCaseIdentifiers(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-camel-identifier",
            to: text,
            format: .text(.plain),
        )
    }

    // MARK: Code-Like Line Passes

    static func normalizeCodeHeavyLines(
        _ text: String,
        format: NormalizationFormat,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
    ) -> String {
        let ruleID = switch format {
            case .text:
                "base-text-code-line"
            case .source:
                "base-source-line"
        }

        return applySingleBaseRule(
            id: ruleID,
            to: text,
            format: format,
            nestedFormat: nestedFormat,
        )
    }

    // MARK: Natural Language Passes

    static func normalizeSpiralProneWords(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-repeated-letter-run",
            to: text,
            format: .text(.plain),
        )
    }

    // MARK: Base Rule Helpers

    private static func applySingleBaseRule(
        id: String,
        to text: String,
        format: NormalizationFormat,
        context: TextForSpeech.Context? = nil,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
    ) -> String {
        guard let rule = TextForSpeech.Profile.base.replacement(id: id) else { return text }

        return applyReplacementRules(
            text,
            profile: TextForSpeech.Profile(
                id: "base-\(id)",
                name: "Base \(id)",
                replacements: [rule],
            ),
            format: format,
            phase: .beforeBuiltIns,
            context: context,
            nestedFormat: nestedFormat,
        )
    }
}
