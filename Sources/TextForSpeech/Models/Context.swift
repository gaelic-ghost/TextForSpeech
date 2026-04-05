import Foundation

// MARK: - Context

public extension TextForSpeech {
    struct Context: Codable, Sendable, Equatable {
        public let cwd: String?
        public let repoRoot: String?
        public let format: Format?

        public init(
            cwd: String? = nil,
            repoRoot: String? = nil,
            format: Format? = nil
        ) {
            self.cwd = Context.normalizedPath(cwd)
            self.repoRoot = Context.normalizedPath(repoRoot)
            self.format = format
        }

        private static func normalizedPath(_ path: String?) -> String? {
            guard let trimmed = path?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
                return nil
            }

            let standardized = NSString(string: trimmed).standardizingPath
            return standardized.isEmpty ? nil : standardized
        }
    }
}
