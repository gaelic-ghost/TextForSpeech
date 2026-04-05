import Foundation

// MARK: - Namespace

public enum TextForSpeech {}

// MARK: - Public API

public extension TextForSpeech {
    // MARK: Text Normalization

    static func normalizeText(
        _ text: String,
        context: Context? = nil,
        profile: Profile = .default,
        format: TextFormat? = nil,
        nestedFormat: SourceFormat? = nil
    ) -> String {
        TextNormalizer.normalizeText(
            text,
            context: context,
            profile: profile,
            format: format,
            nestedFormat: nestedFormat
        )
    }

    // MARK: Source Normalization

    static func normalizeSource(
        _ source: String,
        as format: SourceFormat,
        context: Context? = nil,
        profile: Profile = .default
    ) -> String {
        SourceNormalizer.normalize(
            source,
            as: format,
            context: context,
            profile: profile
        )
    }

    // MARK: Legacy Compatibility

    static func normalize(
        _ text: String,
        context: Context? = nil,
        profile: Profile = .default,
        as format: Format? = nil
    ) -> String {
        TextNormalizer.normalizeLegacy(
            text,
            context: context,
            profile: .base.merged(with: profile),
            format: format
        )
    }

    // MARK: Detection

    static func detectTextFormat(in text: String) -> TextFormat {
        TextNormalizer.detectTextFormat(in: text)
    }

    static func detectFormat(in text: String) -> Format {
        TextNormalizer.detectLegacyFormat(in: text)
    }

    // MARK: Forensics

    static func forensicFeatures(
        originalText: String,
        normalizedText: String
    ) -> ForensicFeatures {
        TextNormalizer.forensicFeatures(originalText: originalText, normalizedText: normalizedText)
    }

    static func sections(originalText: String) -> [Section] {
        TextNormalizer.sections(originalText: originalText)
    }

    static func sectionWindows(
        originalText: String,
        totalDurationMS: Int,
        totalChunkCount: Int
    ) -> [SectionWindow] {
        TextNormalizer.sectionWindows(
            originalText: originalText,
            totalDurationMS: totalDurationMS,
            totalChunkCount: totalChunkCount
        )
    }

    static func words(in text: String) -> [String] {
        TextNormalizer.naturalLanguageWords(in: text)
    }
}
