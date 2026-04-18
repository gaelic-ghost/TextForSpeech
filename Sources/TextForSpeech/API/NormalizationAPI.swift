import Foundation

public extension TextForSpeech {
    enum Normalize {}
}

public extension TextForSpeech.Normalize {
    static func text(
        _ text: String,
        context: TextForSpeech.Context? = nil,
        customProfile: TextForSpeech.Profile = .default,
        style: TextForSpeech.BuiltInProfileStyle = .balanced,
        format: TextForSpeech.TextFormat? = nil,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
    ) -> String {
        TextNormalizer.normalizeText(
            text,
            context: context,
            profile: TextForSpeech.Profile.builtInBase(style: style).merged(with: customProfile),
            format: format,
            nestedFormat: nestedFormat,
        )
    }

    static func source(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        context: TextForSpeech.Context? = nil,
        customProfile: TextForSpeech.Profile = .default,
        style: TextForSpeech.BuiltInProfileStyle = .balanced,
    ) -> String {
        SourceNormalizer.normalize(
            source,
            as: format,
            context: context,
            profile: customProfile,
            style: style,
        )
    }

    static func detectTextFormat(in text: String) -> TextForSpeech.TextFormat {
        TextNormalizer.detectTextFormat(in: text)
    }
}
