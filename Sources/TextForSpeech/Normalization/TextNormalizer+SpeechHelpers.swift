import Foundation

// MARK: - Speech Helpers

extension TextNormalizer {
    static func spelledOut(_ text: String) -> String {
        text.map { String($0) }.joined(separator: " ")
    }

    static func spokenCodeBlock(
        _ body: String,
        nestedFormat: TextForSpeech.SourceFormat? = nil
    ) -> String {
        let spoken = spokenEmbeddedCode(body, nestedFormat: nestedFormat)
        return spoken.isEmpty ? "Code sample." : "Code sample. \(spoken). End code sample."
    }

    static func spokenInlineCode(
        _ body: String,
        nestedFormat: TextForSpeech.SourceFormat? = nil
    ) -> String {
        let spoken = spokenEmbeddedCode(body, nestedFormat: nestedFormat)
        return spoken.isEmpty ? " code " : " \(spoken) "
    }

    static func spokenEmbeddedCode(
        _ body: String,
        nestedFormat: TextForSpeech.SourceFormat? = nil
    ) -> String {
        if let nestedFormat {
            return SourceNormalizer.normalizeEmbedded(body, as: nestedFormat)
        }

        return spokenCode(body)
    }

    static func spokenSource(_ text: String, format: TextForSpeech.SourceFormat) -> String {
        switch format {
        case .generic, .swift, .python, .rust:
            spokenCode(text)
        }
    }

    static func spokenSegment(_ text: String) -> String {
        let broken = insertWordBreaks(in: text)
        let words = naturalLanguageWords(in: broken)
        if words.isEmpty {
            return broken
        }
        return words.joined(separator: " ")
    }

    static func insertWordBreaks(in text: String) -> String {
        guard !text.isEmpty else { return text }

        var output = ""
        var previous: Character?

        for character in text {
            defer { previous = character }

            guard let previous else {
                output.append(character)
                continue
            }

            let needsBreak =
                (previous.isLowercase && character.isUppercase)
                || (previous.isLetter && character.isNumber)
                || (previous.isNumber && character.isLetter)

            if needsBreak, output.last != " " {
                output.append(" ")
            }

            output.append(character)
        }

        return output
    }
}
