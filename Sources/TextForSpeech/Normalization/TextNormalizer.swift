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

    static func normalizeLegacy(
        _ text: String,
        context: TextForSpeech.Context? = nil,
        profile: TextForSpeech.Profile = .default,
        format: TextForSpeech.Format? = nil
    ) -> String {
        let resolvedFormat = format ?? context?.format ?? detectLegacyFormat(in: text)
        if let sourceFormat = resolvedFormat.sourceFormat {
            return normalizeSource(
                text,
                context: context,
                profile: profile,
                format: sourceFormat
            )
        }

        return normalizeText(
            text,
            context: context,
            profile: profile,
            format: resolvedFormat.textFormat
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
            phase: .beforeNormalization
        )
        let normalized = passes.reduce(seeded) { partial, pass in
            pass(partial, context, profile, format, nestedFormat)
        }
        let finalized = collapseWhitespace(
            applyReplacementRules(
                normalized,
                profile: profile,
                format: format,
                phase: .afterNormalization
            )
        )
        return finalized.isEmpty ? text : finalized
    }

    static func forensicFeatures(
        originalText: String,
        normalizedText: String
    ) -> TextForSpeech.ForensicFeatures {
        let tokens = candidateTokens(in: originalText)

        return TextForSpeech.ForensicFeatures(
            originalCharacterCount: originalText.count,
            normalizedCharacterCount: normalizedText.count,
            normalizedCharacterDelta: normalizedText.count - originalText.count,
            originalParagraphCount: paragraphCount(in: originalText),
            normalizedParagraphCount: paragraphCount(in: normalizedText),
            markdownHeaderCount: originalText.split(separator: "\n", omittingEmptySubsequences: false)
                .count(where: { markdownHeaderTitle(in: String($0)) != nil }),
            fencedCodeBlockCount: fencedCodeBlockBodies(in: originalText).count,
            inlineCodeSpanCount: inlineCodeBodies(in: originalText).count,
            markdownLinkCount: markdownLinks(in: originalText).count,
            urlCount: tokens.count(where: isLikelyURL),
            filePathCount: filePathFragments(in: originalText).count,
            dottedIdentifierCount: tokens.count(where: isLikelyDottedIdentifier),
            camelCaseTokenCount: tokens.count(where: isLikelyCamelCaseIdentifier),
            snakeCaseTokenCount: tokens.count(where: isLikelySnakeCaseIdentifier),
            objcSymbolCount: tokens.count(where: isLikelyObjectiveCSymbol),
            repeatedLetterRunCount: tokens.count(where: containsRepeatedLetterRun)
        )
    }

    static func sections(originalText: String) -> [TextForSpeech.Section] {
        let sections = splitSections(in: originalText)
        let weightedCounts = sections.map { max(normalizeText($0.text).count, 1) }
        let totalWeightedCount = max(weightedCounts.reduce(0, +), 1)

        return sections.enumerated().map { index, section in
            TextForSpeech.Section(
                index: index + 1,
                title: section.title,
                kind: section.kind,
                originalCharacterCount: section.text.count,
                normalizedCharacterCount: weightedCounts[index],
                normalizedCharacterShare: Double(weightedCounts[index]) / Double(totalWeightedCount)
            )
        }
    }

    static func sectionWindows(
        originalText: String,
        totalDurationMS: Int,
        totalChunkCount: Int
    ) -> [TextForSpeech.SectionWindow] {
        let sections = sections(originalText: originalText)
        guard !sections.isEmpty else { return [] }

        var elapsedMS = 0
        var elapsedChunks = 0

        return sections.enumerated().map { index, section in
            let isLastSection = index == sections.count - 1
            let remainingDurationMS = max(totalDurationMS - elapsedMS, 0)
            let remainingChunkCount = max(totalChunkCount - elapsedChunks, 0)
            let durationMS = isLastSection
                ? remainingDurationMS
                : min(
                    remainingDurationMS,
                    max(Int((Double(totalDurationMS) * section.normalizedCharacterShare).rounded()), 0)
                )
            let chunkCount = isLastSection
                ? remainingChunkCount
                : min(
                    remainingChunkCount,
                    max(Int((Double(totalChunkCount) * section.normalizedCharacterShare).rounded()), 0)
                )

            let window = TextForSpeech.SectionWindow(
                section: section,
                estimatedStartMS: elapsedMS,
                estimatedEndMS: elapsedMS + durationMS,
                estimatedDurationMS: durationMS,
                estimatedStartChunk: elapsedChunks,
                estimatedEndChunk: elapsedChunks + chunkCount
            )

            elapsedMS += durationMS
            elapsedChunks += chunkCount
            return window
        }
    }

    static func detectTextFormat(in text: String) -> TextForSpeech.TextFormat {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plain }

        if looksLikeHTML(trimmed) {
            return .html
        }

        if looksLikeMarkdownList(trimmed) {
            return .list
        }

        if looksLikeMarkdown(trimmed) {
            return .markdown
        }

        if looksLikeCLIOutput(trimmed) {
            return .cli
        }

        if looksLikeLogOutput(trimmed) {
            return .log
        }

        return .plain
    }

    static func detectLegacyFormat(in text: String) -> TextForSpeech.Format {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .plain }

        if looksLikeHTML(trimmed) {
            return .html
        }

        if looksLikeMarkdownList(trimmed) {
            return .list
        }

        if looksLikeMarkdown(trimmed) {
            return .markdown
        }

        if looksLikeSwiftSource(trimmed) {
            return .swift
        }

        if looksLikePythonSource(trimmed) {
            return .python
        }

        if looksLikeRustSource(trimmed) {
            return .rust
        }

        if looksLikeCLIOutput(trimmed) {
            return .cli
        }

        if looksLikeLogOutput(trimmed) {
            return .log
        }

        return .plain
    }
}
