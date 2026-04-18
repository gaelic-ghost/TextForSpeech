import Foundation

// MARK: - Runtime Style

public extension TextForSpeech.Runtime {
    struct Style {
        public struct Option: Sendable, Equatable, Identifiable {
            public let style: TextForSpeech.BuiltInProfileStyle
            public let summary: String

            public var id: TextForSpeech.BuiltInProfileStyle { style }
        }

        let runtime: TextForSpeech.Runtime

        init(runtime: TextForSpeech.Runtime) {
            self.runtime = runtime
        }
    }
}
