import Foundation

public extension TextForSpeech {
    enum SummarizationProvider: String, Codable, Sendable, Equatable, CaseIterable, Identifiable {
        case codexExec
        case openAIResponses
        case foundationModels

        public var id: String { rawValue }
    }
}
