import Foundation
import NaturalLanguage
import RegexBuilder

enum TextNormalizer {
    // MARK: Pass Types

    typealias NormalizationPass = (String) -> String
    typealias ContextualNormalizationPass =
        (
            String,
            TextForSpeech.RequestContext?,
            TextForSpeech.Profile,
            NormalizationFormat,
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
            { text, requestContext, profile, _ in
                normalizeFencedCodeBlocks(
                    text,
                    requestContext: requestContext,
                    profile: profile,
                )
            },
            { text, requestContext, profile, _ in
                normalizeInlineCodeSpans(
                    text,
                    requestContext: requestContext,
                    profile: profile,
                )
            },
            { text, _, _, _ in normalizeMarkdownLinks(text) },
            { text, _, _, _ in normalizePriorityListItems(text) },
            { text, _, _, _ in normalizeSemanticLinkRuns(text) },
            { text, requestContext, _, _ in
                compactRepeatedFilePathPrefixes(text, requestContext: requestContext)
            },
            { text, _, _, _ in normalizeSpacedMeasuredValues(text) },
            { text, requestContext, profile, format in
                applyReplacementRules(
                    text,
                    profile: profile,
                    format: format,
                    phase: .beforeBuiltIns,
                    requestContext: requestContext,
                )
            },
            { text, _, _, _ in normalizeWhitespacePreservingLineBreaks(text) },
        ]
    }

    static var sourceNormalizationPasses: [ContextualNormalizationPass] {
        [
            { text, _, _, _ in normalizeSemanticLinkRuns(text) },
            { text, _, _, _ in normalizeSpacedMeasuredValues(text) },
            { text, requestContext, profile, format in
                applyReplacementRules(
                    text,
                    profile: profile,
                    format: format,
                    phase: .beforeBuiltIns,
                    requestContext: requestContext,
                )
            },
            { text, _, _, _ in normalizeWhitespacePreservingLineBreaks(text) },
        ]
    }

    // MARK: Public Entry Points

    static func normalizeText(
        _ text: String,
        requestContext: TextForSpeech.RequestContext? = nil,
        profile: TextForSpeech.Profile = .default,
        format: TextForSpeech.TextFormat? = nil,
    ) -> String {
        let resolvedFormat = format ?? detectTextFormat(in: text)
        return normalize(
            canonicalize(text),
            requestContext: requestContext,
            profile: profile,
            format: .text(resolvedFormat),
            passes: normalizationPasses,
        )
    }

    static func normalizeSource(
        _ source: String,
        requestContext: TextForSpeech.RequestContext? = nil,
        profile: TextForSpeech.Profile = .default,
        format: TextForSpeech.SourceFormat,
    ) -> String {
        normalize(
            canonicalize(source),
            requestContext: requestContext,
            profile: profile,
            format: .source(format),
            passes: sourceNormalizationPasses,
        )
    }

    // MARK: Pipeline Driver

    private static func normalize(
        _ text: String,
        requestContext: TextForSpeech.RequestContext?,
        profile: TextForSpeech.Profile,
        format: NormalizationFormat,
        passes: [ContextualNormalizationPass],
    ) -> String {
        let normalized = passes.reduce(text) { partial, pass in
            pass(partial, requestContext, profile, format)
        }
        let finalized = normalizeWhitespacePreservingLineBreaks(
            applyReplacementRules(
                normalized,
                profile: profile,
                format: format,
                phase: .afterBuiltIns,
                requestContext: requestContext,
            ),
        )
        return finalized.isEmpty ? text : finalized
    }
}
