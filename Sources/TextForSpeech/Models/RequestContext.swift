import Foundation

public extension TextForSpeech {
    struct RequestContext: Codable, Sendable, Equatable {
        enum CodingKeys: String, CodingKey {
            case source
            case app
            case agent
            case project
            case topic
            case attributes
        }

        public let source: String?
        public let app: String?
        public let agent: String?
        public let project: String?
        public let topic: String?
        public let attributes: [String: String]

        public init(
            source: String? = nil,
            app: String? = nil,
            agent: String? = nil,
            project: String? = nil,
            topic: String? = nil,
            attributes: [String: String] = [:],
        ) {
            self.source = source
            self.app = app
            self.agent = agent
            self.project = project
            self.topic = topic
            self.attributes = attributes
        }

        public init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            source = try container.decodeIfPresent(String.self, forKey: .source)
            app = try container.decodeIfPresent(String.self, forKey: .app)
            agent = try container.decodeIfPresent(String.self, forKey: .agent)
            project = try container.decodeIfPresent(String.self, forKey: .project)
            topic = try container.decodeIfPresent(String.self, forKey: .topic)
            attributes = try container.decodeIfPresent([String: String].self, forKey: .attributes) ?? [:]
        }
    }
}
