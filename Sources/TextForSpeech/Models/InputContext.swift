import Foundation

public extension TextForSpeech {
    struct InputContext: Codable, Sendable, Equatable {
        // MARK: Public State

        public let nestedSourceFormat: SourceFormat?

        // MARK: Initializers

        public init(
            nestedSourceFormat: SourceFormat? = nil,
        ) {
            self.nestedSourceFormat = nestedSourceFormat
        }
    }
}
