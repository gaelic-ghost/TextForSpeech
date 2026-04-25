import Foundation

enum SourceNormalizer {
    // MARK: Public Routing

    static func normalize(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        context: TextForSpeech.Context? = nil,
        requestContext: TextForSpeech.RequestContext? = nil,
        profile: TextForSpeech.Profile = .default,
        style: TextForSpeech.BuiltInProfileStyle = .balanced,
    ) -> String {
        TextNormalizer.normalizeSource(
            source,
            context: context,
            requestContext: requestContext,
            profile: TextForSpeech.Profile.builtInBase(style: style).merged(with: profile),
            format: format,
        )
    }

    // MARK: Embedded Routing

    static func normalizeEmbedded(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        requestContext: TextForSpeech.RequestContext? = nil,
        profile: TextForSpeech.Profile = .base,
    ) -> String {
        TextNormalizer.normalizeSource(
            source,
            requestContext: requestContext,
            profile: profile,
            format: format,
        )
    }
}
