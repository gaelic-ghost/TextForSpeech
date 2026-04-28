import Foundation

public extension TextForSpeech {
    struct SummaryConfiguration: Codable, Sendable, Equatable, Identifiable {
        public let provider: SummaryProvider

        public var id: SummaryProvider { provider }

        public init(provider: SummaryProvider = .foundationModels) {
            self.provider = provider
        }

        public static let `default` = SummaryConfiguration()
        public static let localFoundationModels = SummaryConfiguration(provider: .foundationModels)
        public static let openAIResponses = SummaryConfiguration(provider: .openAIResponses)
        public static let codexExec = SummaryConfiguration(provider: .codexExec)
    }

    enum SummaryProvider: String, Codable, Sendable, Equatable, CaseIterable, Identifiable {
        case codexExec
        case openAIResponses
        case foundationModels

        public var id: String { rawValue }
    }
}
