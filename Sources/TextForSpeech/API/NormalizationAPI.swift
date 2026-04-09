import Foundation

// MARK: - Normalization API

public extension TextForSpeech {
    enum Normalize {}
}

public extension TextForSpeech.Normalize {
    static func text(
        _ text: String,
        context: TextForSpeech.Context? = nil,
        profile: TextForSpeech.Profile = .default,
        format: TextForSpeech.TextFormat? = nil,
        nestedFormat: TextForSpeech.SourceFormat? = nil
    ) -> String {
        TextNormalizer.normalizeText(
            text,
            context: context,
            profile: TextForSpeech.mergedBuiltInProfile(with: profile),
            format: format,
            nestedFormat: nestedFormat
        )
    }

    static func source(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        context: TextForSpeech.Context? = nil,
        profile: TextForSpeech.Profile = .default
    ) -> String {
        SourceNormalizer.normalize(
            source,
            as: format,
            context: context,
            profile: TextForSpeech.mergedBuiltInProfile(with: profile)
        )
    }

    static func detectTextFormat(in text: String) -> TextForSpeech.TextFormat {
        TextNormalizer.detectTextFormat(in: text)
    }
}
