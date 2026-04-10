import Foundation

// MARK: - Source Normalizer

enum SourceNormalizer {
    // MARK: Public Routing

    static func normalize(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        context: TextForSpeech.Context? = nil,
        profile: TextForSpeech.Profile = .default,
        style: TextForSpeech.BuiltInProfileStyle = .balanced
    ) -> String {
        TextNormalizer.normalizeSource(
            source,
            context: context,
            profile: TextForSpeech.Profile.builtInBase(style: style).merged(with: profile),
            format: format
        )
    }

    // MARK: Embedded Routing

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
