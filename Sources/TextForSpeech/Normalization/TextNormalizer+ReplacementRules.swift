import Foundation

// MARK: - Replacement Rules

extension TextNormalizer {
    static func paragraphCount(in text: String) -> Int {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return 0 }

        return trimmed
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .count
    }

    static func transformTokens(in text: String, transform: (String) -> String?) -> String {
        var result = ""
        var index = text.startIndex

        while index < text.endIndex {
            guard !text[index].isWhitespace else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }

            let start = index
            while index < text.endIndex, !text[index].isWhitespace {
                index = text.index(after: index)
            }

            let rawToken = String(text[start..<index])
            result += transformedToken(rawToken, transform: transform)
        }

        return result
    }

    static func applyReplacementRules(
        _ text: String,
        profile: TextForSpeech.Profile,
        format: NormalizationFormat,
        phase: TextForSpeech.Replacement.Phase
    ) -> String {
        let replacements: [TextForSpeech.Replacement] = switch format {
        case .text(let textFormat):
            profile.replacements(for: phase, in: textFormat)
        case .source(let sourceFormat):
            profile.replacements(for: phase, in: sourceFormat)
        }

        return replacements.reduce(text) { partial, rule in
            applyReplacementRule(rule, to: partial)
        }
    }

    static func transformedToken(_ rawToken: String, transform: (String) -> String?) -> String {
        let punctuation = CharacterSet(charactersIn: "\"'()[]{}<>.,;:!?")
        var start = rawToken.startIndex
        var end = rawToken.endIndex

        while start < end,
            rawToken[start].unicodeScalars.allSatisfy({ punctuation.contains($0) })
        {
            start = rawToken.index(after: start)
        }

        while end > start {
            let beforeEnd = rawToken.index(before: end)
            guard rawToken[beforeEnd].unicodeScalars.allSatisfy({ punctuation.contains($0) }) else {
                break
            }
            end = beforeEnd
        }

        let prefix = rawToken[..<start]
        let core = String(rawToken[start..<end])
        let suffix = rawToken[end...]

        guard !core.isEmpty, let replacement = transform(core) else {
            return rawToken
        }

        return "\(prefix)\(replacement)\(suffix)"
    }

    static func trimmedCandidateToken(_ token: String) -> String {
        let punctuation = CharacterSet(charactersIn: "\"'()[]{}<>.,;:!?")
        var start = token.startIndex
        var end = token.endIndex

        while start < end,
            token[start].unicodeScalars.allSatisfy({ punctuation.contains($0) })
        {
            start = token.index(after: start)
        }

        while end > start {
            let beforeEnd = token.index(before: end)
            guard token[beforeEnd].unicodeScalars.allSatisfy({ punctuation.contains($0) }) else {
                break
            }
            end = beforeEnd
        }

        return String(token[start..<end])
    }

    private static func applyReplacementRule(
        _ rule: TextForSpeech.Replacement,
        to text: String
    ) -> String {
        guard !rule.text.isEmpty else { return text }

        switch rule.match {
        case .phrase:
            return text.replacingOccurrences(
                of: rule.text,
                with: rule.replacement,
                options: rule.isCaseSensitive ? [] : [.caseInsensitive]
            )

        case .token:
            return transformTokens(in: text) { token in
                tokenMatches(rule.text, token: token, caseSensitive: rule.isCaseSensitive)
                    ? rule.replacement
                    : nil
            }
        }
    }

    private static func tokenMatches(_ expected: String, token: String, caseSensitive: Bool) -> Bool {
        caseSensitive
            ? token == expected
            : token.compare(expected, options: [.caseInsensitive]) == .orderedSame
    }
}
