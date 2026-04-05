import Foundation

// MARK: - Context

public extension TextForSpeech {
    struct Context: Codable, Sendable, Equatable {
        public let cwd: String?
        public let repoRoot: String?
        public let textFormat: TextFormat?
        public let nestedSourceFormat: SourceFormat?

        public init(
            cwd: String? = nil,
            repoRoot: String? = nil,
            textFormat: TextFormat? = nil,
            nestedSourceFormat: SourceFormat? = nil
        ) {
            self.cwd = Context.normalizedPath(cwd)
            self.repoRoot = Context.normalizedPath(repoRoot)
            self.textFormat = textFormat
            self.nestedSourceFormat = nestedSourceFormat
        }

        public init(
            cwd: String? = nil,
            repoRoot: String? = nil,
            format: Format? = nil
        ) {
            self.init(
                cwd: cwd,
                repoRoot: repoRoot,
                textFormat: format?.textFormat,
                nestedSourceFormat: format?.sourceFormat
            )
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

public extension TextForSpeech.Context {
    var format: TextForSpeech.Format? {
        if let textFormat {
            return TextForSpeech.Format(textFormat)
        }

        if let nestedSourceFormat {
            return TextForSpeech.Format(nestedSourceFormat)
        }

        return nil
    }
}
