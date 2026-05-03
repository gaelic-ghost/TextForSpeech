import Foundation

public extension TextForSpeech {
    struct InputContext: Codable, Sendable, Equatable {
        // MARK: Public State

        public let cwd: String?
        public let repoRoot: String?
        public let nestedSourceFormat: SourceFormat?

        // MARK: Initializers

        public init(
            cwd: String? = nil,
            repoRoot: String? = nil,
            nestedSourceFormat: SourceFormat? = nil,
        ) {
            self.cwd = InputContext.normalizedPath(cwd)
            self.repoRoot = InputContext.normalizedPath(repoRoot)
            self.nestedSourceFormat = nestedSourceFormat
        }

        // MARK: Helpers

        private static func normalizedPath(_ path: String?) -> String? {
            guard let trimmed = path?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }

            let standardized = NSString(string: trimmed).standardizingPath
            return standardized.isEmpty ? nil : standardized
        }
    }
}
