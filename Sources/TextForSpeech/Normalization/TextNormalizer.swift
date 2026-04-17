import Foundation
import NaturalLanguage
import RegexBuilder

// MARK: - Normalizer

enum TextNormalizer {
    // MARK: Pass Types

    typealias NormalizationPass = (String) -> String
    typealias ContextualNormalizationPass =
        (
            String,
            TextForSpeech.Context?,
            TextForSpeech.Profile,
            NormalizationFormat,
            TextForSpeech.SourceFormat?,
        ) -> String

    // MARK: Detection Markers

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

    // MARK: Pass Pipelines

    static var normalizationPasses: [ContextualNormalizationPass] {
        [
            { text, context, _, _, nestedFormat in
                normalizeFencedCodeBlocks(text, context: context, nestedFormat: nestedFormat)
            },
            { text, context, _, _, nestedFormat in
                normalizeInlineCodeSpans(text, context: context, nestedFormat: nestedFormat)
            },
            { text, _, _, _, _ in normalizeMarkdownLinks(text) },
            { text, context, _, _, _ in
                compactRepeatedFilePathPrefixes(text, context: context)
            },
            { text, context, profile, format, nestedFormat in
                applyReplacementRules(
                    text,
                    profile: profile,
                    format: format,
                    phase: .beforeBuiltIns,
                    context: context,
                    nestedFormat: nestedFormat,
                )
            },
            { text, _, _, _, _ in collapseWhitespace(text) },
        ]
    }

    static var sourceNormalizationPasses: [ContextualNormalizationPass] {
        [
            { text, context, profile, format, nestedFormat in
                applyReplacementRules(
                    text,
                    profile: profile,
                    format: format,
                    phase: .beforeBuiltIns,
                    context: context,
                    nestedFormat: nestedFormat,
                )
            },
            { text, _, _, _, _ in collapseWhitespace(text) },
        ]
    }

    // MARK: Public Entry Points

    static func normalizeText(
        _ text: String,
        context: TextForSpeech.Context? = nil,
        profile: TextForSpeech.Profile = .default,
        format: TextForSpeech.TextFormat? = nil,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
    ) -> String {
        let resolvedFormat = format ?? context?.textFormat ?? detectTextFormat(in: text)
        return normalize(
            canonicalize(text),
            context: context,
            profile: profile,
            format: .text(resolvedFormat),
            nestedFormat: nestedFormat ?? context?.nestedSourceFormat,
            passes: normalizationPasses,
        )
    }

    static func normalizeSource(
        _ source: String,
        context: TextForSpeech.Context? = nil,
        profile: TextForSpeech.Profile = .default,
        format: TextForSpeech.SourceFormat,
    ) -> String {
        normalize(
            canonicalize(source),
            context: context,
            profile: profile,
            format: .source(format),
            passes: sourceNormalizationPasses,
        )
    }

    // MARK: Pipeline Driver

    private static func normalize(
        _ text: String,
        context: TextForSpeech.Context?,
        profile: TextForSpeech.Profile,
        format: NormalizationFormat,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
        passes: [ContextualNormalizationPass],
    ) -> String {
        let normalized = passes.reduce(text) { partial, pass in
            pass(partial, context, profile, format, nestedFormat)
        }
        let finalized = collapseWhitespace(
            applyReplacementRules(
                normalized,
                profile: profile,
                format: format,
                phase: .afterBuiltIns,
                context: context,
                nestedFormat: nestedFormat,
            ),
        )
        return finalized.isEmpty ? text : finalized
    }
}
