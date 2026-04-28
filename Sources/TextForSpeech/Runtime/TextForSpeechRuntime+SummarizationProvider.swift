import Foundation

public extension TextForSpeech.Runtime {
    struct SummarizationProviderSettings {
        public struct Option: Sendable, Equatable, Identifiable {
            public let provider: TextForSpeech.SummarizationProvider
            public let summary: String

            public var id: TextForSpeech.SummarizationProvider.ID { provider.id }
        }

        let runtime: TextForSpeech.Runtime

        init(runtime: TextForSpeech.Runtime) {
            self.runtime = runtime
        }
    }
}

public extension TextForSpeech.Runtime.SummarizationProviderSettings {
    func get() -> TextForSpeech.SummarizationProvider {
        runtime.activeSummarizationProvider
    }

    func list() -> [Option] {
        TextForSpeech.SummarizationProvider.allCases.map(Self.option(for:))
    }

    func set(_ provider: TextForSpeech.SummarizationProvider) throws {
        runtime.activeSummarizationProvider = provider
        try runtime.persistCurrentState()
    }

    private static func option(for provider: TextForSpeech.SummarizationProvider) -> Option {
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
