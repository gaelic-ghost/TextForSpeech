import Foundation
import NaturalLanguage
import RegexBuilder

// MARK: - Normalizer

enum TextNormalizer {
    typealias NormalizationPass = (String) -> String
    typealias ContextualNormalizationPass =
        (
            String,
            TextForSpeech.Context?,
            TextForSpeech.Profile,
            NormalizationFormat,
            TextForSpeech.SourceFormat?
        ) -> String

    static var codeMarkerRegex: Regex<Substring> {
        Regex {
            ChoiceOf {
                "```"
                "`"
                "->"
                "=>"
                "::"
                "?."
                "??"
                "&&"
                "||"
                "=="
                "!="
                "{"
                "}"
                "</"
                "/>"
                "func "
                "let "
                "var "
                "const "
                "class "
                "struct "
                "enum "
                "return "
            }
        }
    }

    static var normalizationPasses: [ContextualNormalizationPass] {
        [
            { text, _, _, _, nestedFormat in
                normalizeFencedCodeBlocks(text, nestedFormat: nestedFormat)
            },
            { text, _, _, _, nestedFormat in
                normalizeInlineCodeSpans(text, nestedFormat: nestedFormat)
            },
            { text, _, _, _, _ in normalizeMarkdownLinks(text) },
            { text, _, _, _, _ in normalizeURLs(text) },
            { text, _, _, _, _ in normalizeStandaloneGaleAliases(text) },
            normalizeFilePaths,
            { text, _, _, _, _ in normalizeDottedIdentifiers(text) },
            { text, _, _, _, _ in normalizeSnakeCaseIdentifiers(text) },
            { text, _, _, _, _ in normalizeDashedIdentifiers(text) },
            { text, _, _, _, _ in normalizeCamelCaseIdentifiers(text) },
            { text, _, _, format, nestedFormat in
                normalizeCodeHeavyLines(text, format: format, nestedFormat: nestedFormat)
            },
            { text, _, _, _, _ in normalizeSpiralProneWords(text) },
            { text, _, _, _, _ in collapseWhitespace(text) },
        ]
    }

    static var sourceNormalizationPasses: [ContextualNormalizationPass] {
        [
            { text, _, _, _, _ in normalizeStandaloneGaleAliases(text) },
            normalizeFilePaths,
            { text, _, _, format, _ in
                guard case .source(let sourceFormat) = format else { return text }
                return normalizeStructuredSourceLines(text, format: sourceFormat)
            },
            { text, _, _, _, _ in normalizeSpiralProneWords(text) },
            { text, _, _, _, _ in collapseWhitespace(text) },
        ]
    }

    // MARK: Public API

    static func normalizeText(
        _ text: String,
        context: TextForSpeech.Context? = nil,
        profile: TextForSpeech.Profile = .default,
        format: TextForSpeech.TextFormat? = nil,
        nestedFormat: TextForSpeech.SourceFormat? = nil
    ) -> String {
        let resolvedFormat = format ?? context?.textFormat ?? detectTextFormat(in: text)
        return normalize(
            canonicalize(text),
            context: context,
            profile: profile,
            format: .text(resolvedFormat),
            nestedFormat: nestedFormat ?? context?.nestedSourceFormat,
            passes: normalizationPasses
        )
    }

    static func normalizeSource(
        _ source: String,
        context: TextForSpeech.Context? = nil,
        profile: TextForSpeech.Profile = .default,
        format: TextForSpeech.SourceFormat
    ) -> String {
        normalize(
            canonicalize(source),
            context: context,
            profile: profile,
            format: .source(format),
            passes: sourceNormalizationPasses
        )
    }

    private static func normalize(
        _ text: String,
        context: TextForSpeech.Context?,
        profile: TextForSpeech.Profile,
        format: NormalizationFormat,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
        passes: [ContextualNormalizationPass]
    ) -> String {
        let seeded = applyReplacementRules(
            text,
            profile: profile,
            format: format,
            phase: .beforeBuiltIns
        )
        let normalized = passes.reduce(seeded) { partial, pass in
            pass(partial, context, profile, format, nestedFormat)
        }
        let finalized = collapseWhitespace(
            applyReplacementRules(
                normalized,
                profile: profile,
                format: format,
                phase: .afterBuiltIns
            )
        )
        return finalized.isEmpty ? text : finalized
    }

}
