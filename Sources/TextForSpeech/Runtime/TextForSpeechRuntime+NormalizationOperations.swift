import Foundation

public extension TextForSpeech.Runtime.Normalization {
    func text(
        _ text: String,
        context: TextForSpeech.Context? = nil,
        format: TextForSpeech.TextFormat? = nil,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
    ) -> String {
        TextForSpeech.Normalize.text(
            text,
            context: context,
            customProfile: runtime.activeCustomProfile(),
            style: runtime.builtInStyle,
            format: format,
            nestedFormat: nestedFormat,
        )
    }

    func text(
        _ text: String,
        usingProfileID id: String,
        context: TextForSpeech.Context? = nil,
        format: TextForSpeech.TextFormat? = nil,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
    ) throws -> String {
        try TextForSpeech.Normalize.text(
            text,
            context: context,
            customProfile: runtime.storedCustomProfile(id: id),
            style: runtime.builtInStyle,
            format: format,
            nestedFormat: nestedFormat,
        )
    }

    func source(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        context: TextForSpeech.Context? = nil,
    ) -> String {
        TextForSpeech.Normalize.source(
            source,
            as: format,
            context: context,
            customProfile: runtime.activeCustomProfile(),
            style: runtime.builtInStyle,
        )
    }

    func source(
        _ source: String,
        as format: TextForSpeech.SourceFormat,
        usingProfileID id: String,
        context: TextForSpeech.Context? = nil,
    ) throws -> String {
        try TextForSpeech.Normalize.source(
            source,
            as: format,
            context: context,
            customProfile: runtime.storedCustomProfile(id: id),
            style: runtime.builtInStyle,
        )
    }
}
