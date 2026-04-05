import Foundation

// MARK: - Source Normalizer

enum SourceNormalizer {
    static func normalize(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        context: TextForSpeech.Context? = nil,
        profile: TextForSpeech.Profile = .default
    ) -> String {
        TextNormalizer.normalizeSource(
            source,
            context: context,
            profile: profile,
            format: format
        )
    }

    static func normalizeEmbedded(
        _ source: String,
        as format: TextForSpeech.SourceFormat
    ) -> String {
        TextNormalizer.normalizeSource(
            source,
            profile: .base,
            format: format
        )
    }
}
