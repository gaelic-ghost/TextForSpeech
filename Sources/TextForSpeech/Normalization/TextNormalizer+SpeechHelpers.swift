import Foundation

// MARK: - Speech Helpers

extension TextNormalizer {
    private static let spokenWordExpansions: [String: String] = [
        "cos": "cosine",
        "sin": "sine",
        "tan": "tangent",
        "acos": "arc cosine",
        "asin": "arc sine",
        "atan": "arc tangent",
        "f16": "float sixteen",
        "f32": "float thirty two",
        "f64": "float sixty four",
        "i8": "signed integer eight",
        "i16": "signed integer sixteen",
        "i32": "signed integer thirty two",
        "i64": "signed integer sixty four",
        "u8": "unsigned integer eight",
        "u16": "unsigned integer sixteen",
        "u32": "unsigned integer thirty two",
        "u64": "unsigned integer sixty four",
        "isize": "signed integer size",
        "usize": "unsigned integer size",
    ]

    private static let spokenNumericWidths: [String: String] = [
        "8": "eight",
        "16": "sixteen",
        "32": "thirty two",
        "64": "sixty four",
    ]

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
        return expandSpokenWords(words).joined(separator: " ")
    }

    static func insertWordBreaks(in text: String) -> String {
        guard !text.isEmpty else { return text }

        let acronymNormalized = text.replacingOccurrences(
            of: #"([a-z])([A-Z]{2,})([A-Z][a-z])"#,
            with: "$1 $2 $3",
            options: .regularExpression
        )

        var output = ""
        var previous: Character?
        let characters = Array(acronymNormalized)

        for character in characters {
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

    private static func expandSpokenWords(_ words: [String]) -> [String] {
        var expanded: [String] = []
        var index = 0

        while index < words.count {
            let current = words[index]
            let lowercasedCurrent = current.lowercased()

            if let directExpansion = spokenWordExpansions[lowercasedCurrent] {
                expanded.append(directExpansion)
                index += 1
                continue
            }

            if index + 1 < words.count,
               let combinedTypeExpansion = spokenTypedNumericWord(
                   head: lowercasedCurrent,
                   width: words[index + 1]
               )
            {
                expanded.append(combinedTypeExpansion)
                index += 2
                continue
            }

            expanded.append(current)
            index += 1
        }

        return expanded
    }

    private static func spokenTypedNumericWord(head: String, width: String) -> String? {
        guard let spokenWidth = spokenNumericWidths[width] else { return nil }

        switch head {
        case "f", "float":
            return "float \(spokenWidth)"
        case "i", "int":
            return "signed integer \(spokenWidth)"
        case "u", "uint":
            return "unsigned integer \(spokenWidth)"
        default:
            return nil
        }
    }
}
