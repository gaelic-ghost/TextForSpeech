import Foundation

public extension TextForSpeech {
    enum Normalize {}
}

public extension TextForSpeech.Normalize {
    static func text(
        _ text: String,
        withContext context: TextForSpeech.InputContext? = nil,
        requestContext: TextForSpeech.RequestContext? = nil,
        customProfile: TextForSpeech.Profile = .default,
        style: TextForSpeech.BuiltInProfileStyle = .balanced,
        summary: TextForSpeech.SummaryConfiguration = .default,
        summarize: Bool = false,
    ) async throws -> String {
        let textToNormalize = if summarize {
            try await TextSummarizer.summarize(text, configuration: summary)
        } else {
            text
        }

        return TextNormalizer.normalizeText(
            textToNormalize,
            context: context,
            requestContext: requestContext,
            profile: TextForSpeech.Profile.builtInBase(style: style).merged(with: customProfile),
            format: nil,
            nestedFormat: nil,
        )
    }

    static func source(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        withContext context: TextForSpeech.InputContext? = nil,
        requestContext: TextForSpeech.RequestContext? = nil,
        customProfile: TextForSpeech.Profile = .default,
        style: TextForSpeech.BuiltInProfileStyle = .balanced,
        summary: TextForSpeech.SummaryConfiguration = .default,
        summarize: Bool = false,
    ) async throws -> String {
        let normalizedSource = SourceNormalizer.normalize(
            source,
            as: format,
            context: context,
            requestContext: requestContext,
            profile: customProfile,
            style: style,
        )

        if summarize {
            let summarizedSource = try await TextSummarizer.summarize(
                normalizedSource,
                configuration: summary,
            )

            return TextNormalizer.normalizeText(
                summarizedSource,
                context: context,
                requestContext: requestContext,
                profile: TextForSpeech.Profile.builtInBase(style: style).merged(with: customProfile),
                format: .plain,
                nestedFormat: nil,
            )
        } else {
            return normalizedSource
        }
    }

    static func detectTextFormat(in text: String) -> TextForSpeech.TextFormat {
        TextNormalizer.detectTextFormat(in: text)
    }
}
