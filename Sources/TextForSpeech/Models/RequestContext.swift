import Foundation

public extension TextForSpeech {
    struct RequestContext: Codable, Sendable, Equatable {
        enum CodingKeys: String, CodingKey {
            case source
            case topic
            case cwd
            case repoRoot
            case attributes
        }

        public let source: String?
        public let topic: String?
        public let cwd: String?
        public let repoRoot: String?
        public let attributes: [String: String]

        public init(
            source: String? = nil,
            topic: String? = nil,
            cwd: String? = nil,
            repoRoot: String? = nil,
            attributes: [String: String] = [:],
        ) {
            self.source = source
            self.topic = topic
            self.cwd = RequestContext.normalizedPath(cwd)
            self.repoRoot = RequestContext.normalizedPath(repoRoot)
            self.attributes = attributes
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            source = try container.decodeIfPresent(String.self, forKey: .source)
            topic = try container.decodeIfPresent(String.self, forKey: .topic)
            cwd = RequestContext.normalizedPath(try container.decodeIfPresent(String.self, forKey: .cwd))
            repoRoot = RequestContext.normalizedPath(try container.decodeIfPresent(String.self, forKey: .repoRoot))
            attributes = try container.decodeIfPresent([String: String].self, forKey: .attributes) ?? [:]
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

extension TextForSpeech.RequestContext {
    var speechPreface: String? {
        let normalizedSource = normalizedMetadata(source)
        let normalizedTopic = normalizedMetadata(topic)

        return switch (normalizedSource, normalizedTopic) {
            case let (source?, topic?):
                "From \(source), \(topic)."
            case let (source?, nil):
                "From \(source)."
            case let (nil, topic?):
                "About \(topic)."
            case (nil, nil):
                nil
        }
    }

    func prefacing(_ text: String) -> String {
        guard let speechPreface else { return text }
        guard !text.isEmpty else { return speechPreface }
        return "\(speechPreface)\n\n\(text)"
    }

    private func normalizedMetadata(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }
}
