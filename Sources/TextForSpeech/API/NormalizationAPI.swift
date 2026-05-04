import Foundation

public extension TextForSpeech {
    enum Normalize {}
}

public extension TextForSpeech.Normalize {
    static func text(
        _ text: String,
        requestContext: TextForSpeech.RequestContext? = nil,
        customProfile: TextForSpeech.Profile = .default,
        style: TextForSpeech.BuiltInProfileStyle = .balanced,
        summarizationProvider: TextForSpeech.SummarizationProvider = .foundationModels,
        summarize: Bool = false,
    ) async throws -> String {
        let textToNormalize = if summarize {
            try await TextSummarizer.summarize(text, provider: summarizationProvider)
        } else {
            text
        }

        let normalized = TextNormalizer.normalizeText(
            textToNormalize,
            requestContext: requestContext,
            profile: TextForSpeech.Profile.builtInBase(style: style).merged(with: customProfile),
            format: nil,
        )

        return requestContext?.prefacing(normalized) ?? normalized
    }

    static func source(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        requestContext: TextForSpeech.RequestContext? = nil,
        customProfile: TextForSpeech.Profile = .default,
        style: TextForSpeech.BuiltInProfileStyle = .balanced,
        summarizationProvider: TextForSpeech.SummarizationProvider = .foundationModels,
        summarize: Bool = false,
    ) async throws -> String {
        let normalizedSource = SourceNormalizer.normalize(
            source,
            as: format,
            requestContext: requestContext,
            profile: customProfile,
            style: style,
        )

        if summarize {
            let summarizedSource = try await TextSummarizer.summarize(
                normalizedSource,
                provider: summarizationProvider,
            )

            let normalized = TextNormalizer.normalizeText(
                summarizedSource,
                requestContext: requestContext,
                profile: TextForSpeech.Profile.builtInBase(style: style).merged(with: customProfile),
                format: .plain,
            )

            return requestContext?.prefacing(normalized) ?? normalized
        } else {
            return requestContext?.prefacing(normalizedSource) ?? normalizedSource
        }
    }

    static func detectTextFormat(in text: String) -> TextForSpeech.TextFormat {
        TextNormalizer.detectTextFormat(in: text)
    }
}
