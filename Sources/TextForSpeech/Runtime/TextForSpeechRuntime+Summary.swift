import Foundation

public extension TextForSpeech.Runtime {
    struct SummarySettings {
        public struct Option: Sendable, Equatable, Identifiable {
            public let configuration: TextForSpeech.SummaryConfiguration
            public let summary: String

            public var id: TextForSpeech.SummaryConfiguration.ID { configuration.id }
        }

        let runtime: TextForSpeech.Runtime

        init(runtime: TextForSpeech.Runtime) {
            self.runtime = runtime
        }
    }
}

public extension TextForSpeech.Runtime.SummarySettings {
    func get() -> TextForSpeech.SummaryConfiguration {
        runtime.activeSummaryConfiguration
    }

    func list() -> [Option] {
        TextForSpeech.SummaryProvider.allCases.map {
            Self.option(for: TextForSpeech.SummaryConfiguration(provider: $0))
        }
    }

    func set(_ configuration: TextForSpeech.SummaryConfiguration) throws {
        runtime.activeSummaryConfiguration = configuration
        try runtime.persistCurrentState()
    }

    private static func option(for configuration: TextForSpeech.SummaryConfiguration) -> Option {
        let summary = switch configuration.provider {
            case .codexExec:
                "Runs summarization through the local Codex CLI with codex exec."
            case .openAIResponses:
                "Calls the OpenAI Responses API with OPENAI_API_KEY from the process environment."
            case .foundationModels:
                "Uses Apple's on-device Foundation Models framework when available on this device."
        }

        return Option(configuration: configuration, summary: summary)
    }
}
