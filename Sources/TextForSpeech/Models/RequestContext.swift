import Foundation

public extension TextForSpeech {
    struct RequestContext: Codable, Sendable, Equatable {
        enum CodingKeys: String, CodingKey {
            case source
            case app
            case agent
            case project
            case topic
            case cwd
            case repoRoot
            case attributes
        }

        public let source: String?
        public let app: String?
        public let agent: String?
        public let project: String?
        public let topic: String?
        public let cwd: String?
        public let repoRoot: String?
        public let attributes: [String: String]

        public init(
            source: String? = nil,
            app: String? = nil,
            agent: String? = nil,
            project: String? = nil,
            topic: String? = nil,
            cwd: String? = nil,
            repoRoot: String? = nil,
            attributes: [String: String] = [:],
        ) {
            self.source = source
            self.app = app
            self.agent = agent
            self.project = project
            self.topic = topic
            self.cwd = RequestContext.normalizedPath(cwd)
            self.repoRoot = RequestContext.normalizedPath(repoRoot)
            self.attributes = attributes
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            source = try container.decodeIfPresent(String.self, forKey: .source)
            app = try container.decodeIfPresent(String.self, forKey: .app)
            agent = try container.decodeIfPresent(String.self, forKey: .agent)
            project = try container.decodeIfPresent(String.self, forKey: .project)
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
