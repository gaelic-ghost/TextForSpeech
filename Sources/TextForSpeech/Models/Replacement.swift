import Foundation

// MARK: - Replacement

public extension TextForSpeech {
    struct Replacement: Codable, Sendable, Equatable, Identifiable {
        public enum Match: String, Codable, Sendable {
            case exactPhrase = "exact_phrase"
            case wholeToken = "whole_token"
        }

        public enum Phase: String, Codable, Sendable {
            case beforeBuiltIns = "before_built_ins"
            case afterBuiltIns = "after_built_ins"
        }

        public let id: String
        public let text: String
        public let replacement: String
        public let match: Match
        public let phase: Phase
        public let isCaseSensitive: Bool
        public let textFormats: Set<TextFormat>
        public let sourceFormats: Set<SourceFormat>
        public let priority: Int

        public init(
            _ text: String,
            with replacement: String,
            id: String = UUID().uuidString,
            matching match: Match = .exactPhrase,
            during phase: Phase = .beforeBuiltIns,
            caseSensitive isCaseSensitive: Bool = false,
            forTextFormats textFormats: Set<TextFormat> = [],
            forSourceFormats sourceFormats: Set<SourceFormat> = [],
            priority: Int = 0
        ) {
            self.id = id
            self.text = text
            self.replacement = replacement
            self.match = match
            self.phase = phase
            self.isCaseSensitive = isCaseSensitive
            self.textFormats = textFormats
            self.sourceFormats = sourceFormats
            self.priority = priority
        }

        public func applies(to format: TextFormat) -> Bool {
            guard !textFormats.isEmpty || !sourceFormats.isEmpty else { return true }
            return textFormats.contains(format)
        }

        public func applies(to format: SourceFormat) -> Bool {
            guard !textFormats.isEmpty || !sourceFormats.isEmpty else { return true }
            return sourceFormats.contains(.generic) || sourceFormats.contains(format)
        }
    }
}
