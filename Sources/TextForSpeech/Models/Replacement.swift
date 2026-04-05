import Foundation

// MARK: - Replacement

public extension TextForSpeech {
    struct Replacement: Codable, Sendable, Equatable, Identifiable {
        public enum Match: String, Codable, Sendable {
            case phrase = "exact_phrase"
            case token = "whole_token"
        }

        public enum Phase: String, Codable, Sendable {
            case beforeNormalization = "before_built_ins"
            case afterNormalization = "after_built_ins"
        }

        public let id: String
        public let text: String
        public let replacement: String
        public let match: Match
        public let phase: Phase
        public let isCaseSensitive: Bool
        public let formats: Set<Format>
        public let priority: Int

        public init(
            _ text: String,
            with replacement: String,
            id: String = UUID().uuidString,
            as match: Match = .phrase,
            in phase: Phase = .beforeNormalization,
            caseSensitive isCaseSensitive: Bool = false,
            for formats: Set<Format> = [],
            priority: Int = 0
        ) {
            self.id = id
            self.text = text
            self.replacement = replacement
            self.match = match
            self.phase = phase
            self.isCaseSensitive = isCaseSensitive
            self.formats = formats
            self.priority = priority
        }

        public init(
            _ text: String,
            with replacement: String,
            id: String = UUID().uuidString,
            as match: Match = .phrase,
            in phase: Phase = .beforeNormalization,
            caseSensitive isCaseSensitive: Bool = false,
            for textFormats: Set<TextFormat>,
            sourceFormats: Set<SourceFormat> = [],
            priority: Int = 0
        ) {
            self.init(
                text,
                with: replacement,
                id: id,
                as: match,
                in: phase,
                caseSensitive: isCaseSensitive,
                for: Set(textFormats.map(Format.init) + sourceFormats.map(Format.init)),
                priority: priority
            )
        }

        public func applies(to format: Format) -> Bool {
            guard !formats.isEmpty else { return true }
            return formats.contains(where: { $0.matches(format) })
        }

        public func applies(to format: TextFormat) -> Bool {
            guard !formats.isEmpty else { return true }
            return formats.contains(Format(format))
        }

        public func applies(to format: SourceFormat) -> Bool {
            guard !formats.isEmpty else { return true }
            return formats.contains(.source) || formats.contains(Format(format))
        }
    }
}
