import Foundation

public extension TextForSpeech.Runtime.Normalization {
    func text(
        _ text: String,
        withContext context: TextForSpeech.InputContext? = nil,
        requestContext: TextForSpeech.RequestContext? = nil,
        summarize: Bool = false,
    ) async throws -> String {
        try await TextForSpeech.Normalize.text(
            text,
            withContext: context,
            requestContext: requestContext,
            customProfile: runtime.activeCustomProfile(),
            style: runtime.builtInStyle,
            summarizationProvider: runtime.activeSummarizationProvider,
            summarize: summarize,
        )
    }

    func text(
        _ text: String,
        usingProfileID id: String,
        withContext context: TextForSpeech.InputContext? = nil,
        requestContext: TextForSpeech.RequestContext? = nil,
        summarize: Bool = false,
    ) async throws -> String {
        try await TextForSpeech.Normalize.text(
            text,
            withContext: context,
            requestContext: requestContext,
            customProfile: runtime.storedCustomProfile(id: id),
            style: runtime.builtInStyle,
            summarizationProvider: runtime.activeSummarizationProvider,
            summarize: summarize,
        )
    }

    func source(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        withContext context: TextForSpeech.InputContext? = nil,
        requestContext: TextForSpeech.RequestContext? = nil,
        summarize: Bool = false,
    ) async throws -> String {
        try await TextForSpeech.Normalize.source(
            source,
            as: format,
            withContext: context,
            requestContext: requestContext,
            customProfile: runtime.activeCustomProfile(),
            style: runtime.builtInStyle,
            summarizationProvider: runtime.activeSummarizationProvider,
            summarize: summarize,
        )
    }

    func source(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        usingProfileID id: String,
        withContext context: TextForSpeech.InputContext? = nil,
        requestContext: TextForSpeech.RequestContext? = nil,
        summarize: Bool = false,
    ) async throws -> String {
        try await TextForSpeech.Normalize.source(
            source,
            as: format,
            withContext: context,
            requestContext: requestContext,
            customProfile: runtime.storedCustomProfile(id: id),
            style: runtime.builtInStyle,
            summarizationProvider: runtime.activeSummarizationProvider,
            summarize: summarize,
        )
    }
}
