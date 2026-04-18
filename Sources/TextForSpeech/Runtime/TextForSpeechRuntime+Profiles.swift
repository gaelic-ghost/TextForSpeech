import Foundation

// MARK: - Runtime Profiles

public extension TextForSpeech.Runtime {
    struct Profiles {
        public struct Summary: Sendable, Equatable, Identifiable {
            public let id: String
            public let name: String
            public let replacementCount: Int

            init(profile: TextForSpeech.Profile) {
                id = profile.id
                name = profile.name
                replacementCount = profile.replacements.count
            }
        }

        public struct Details: Sendable, Equatable, Identifiable {
            public let profileID: String
            public let summary: Summary
            public let replacements: [TextForSpeech.Replacement]

            public var id: String { profileID }
        }

        let runtime: TextForSpeech.Runtime

        init(runtime: TextForSpeech.Runtime) {
            self.runtime = runtime
        }
    }
}
