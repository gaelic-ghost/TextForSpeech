import Foundation

// MARK: - Namespace

public enum TextForSpeech {}

// MARK: - Public API

public extension TextForSpeech {
    static func normalize(
        _ text: String,
        context: Context? = nil,
        profile: Profile = .default,
        as format: Format? = nil
    ) -> String {
        TextNormalizer.normalize(
            text,
            context: context,
            profile: .base.merged(with: profile),
            format: format
        )
    }

    static func detectFormat(in text: String) -> Format {
        TextNormalizer.detectFormat(in: text)
    }

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
