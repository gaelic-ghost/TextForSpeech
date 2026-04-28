import Foundation

public extension TextForSpeech.Runtime {
    struct SummaryProviderSettings {
        public struct Option: Sendable, Equatable, Identifiable {
            public let provider: TextForSpeech.SummaryProvider
            public let summary: String

            public var id: TextForSpeech.SummaryProvider { provider }
        }

        let runtime: TextForSpeech.Runtime

        init(runtime: TextForSpeech.Runtime) {
            self.runtime = runtime
        }
    }
}

public extension TextForSpeech.Runtime.SummaryProviderSettings {
    func get() -> TextForSpeech.SummaryProvider {
        runtime.activeSummaryProvider
    }

    func list() -> [Option] {
        TextForSpeech.SummaryProvider.allCases.map(Self.option(for:))
    }

    func set(_ provider: TextForSpeech.SummaryProvider) throws {
        runtime.activeSummaryProvider = provider
        try runtime.persistCurrentState()
    }

    private static func option(for provider: TextForSpeech.SummaryProvider) -> Option {
        let summary = switch provider {
            case .codexExec:
                "Runs summarization through the local Codex CLI with codex exec."
            case .openAIResponses:
                "Calls the OpenAI Responses API with OPENAI_API_KEY from the process environment."
            case .foundationModels:
                "Uses Apple's on-device Foundation Models framework when available on this device."
        }

        return Option(provider: provider, summary: summary)
    }
}
