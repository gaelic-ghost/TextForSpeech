import Foundation

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

    static func applyReplacementRules(
        _ text: String,
        profile: TextForSpeech.Profile,
        format: NormalizationFormat,
        phase: TextForSpeech.Replacement.Phase,
        context: TextForSpeech.Context? = nil,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
    ) -> String {
        let replacements: [TextForSpeech.Replacement] = switch format {
            case let .text(textFormat):
                profile.replacements(for: phase, in: textFormat)
            case let .source(sourceFormat):
                profile.replacements(for: phase, in: sourceFormat)
        }

        return replacements.reduce(text) { partial, rule in
            applyReplacementRule(
                rule,
                to: partial,
                context: context,
                format: format,
                nestedFormat: nestedFormat,
            )
        }
    }

    // MARK: Line and Token Transforms

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

    static func transformTokensStatefully<State>(
        in text: String,
        state: inout State,
        transform: (String, inout State) -> String?,
    ) -> String {
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
            result += transformedToken(rawToken) { token in
                transform(token, &state)
            }
        }

        return result
    }

    static func transformLines(in text: String, transform: (String) -> String?) -> String {
        text
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map { line in
                let rawLine = String(line)
                return transform(rawLine) ?? rawLine
            }
            .joined(separator: "\n")
    }

    static func transformedToken(_ rawToken: String, transform: (String) -> String?) -> String {
        let punctuation = CharacterSet(charactersIn: "\"'()[]{}<>.,;:!?")
        var start = rawToken.startIndex
        var end = rawToken.endIndex

        while start < end,
              !preservesLeadingRelativePathPrefix(in: rawToken, at: start),
              rawToken[start].unicodeScalars.allSatisfy({ punctuation.contains($0) }) {
            start = rawToken.index(after: start)
        }

        while end > start {
            let beforeEnd = rawToken.index(before: end)
            if rawToken[beforeEnd] == ")" {
                let openIndex = rawToken.index(before: beforeEnd)
                if openIndex >= start, rawToken[openIndex] == "(" {
                    break
                }
            }
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
              !preservesLeadingRelativePathPrefix(in: token, at: start),
              token[start].unicodeScalars.allSatisfy({ punctuation.contains($0) }) {
            start = token.index(after: start)
        }

        while end > start {
            let beforeEnd = token.index(before: end)
            if token[beforeEnd] == ")" {
                let openIndex = token.index(before: beforeEnd)
                if openIndex >= start, token[openIndex] == "(" {
                    break
                }
            }
            guard token[beforeEnd].unicodeScalars.allSatisfy({ punctuation.contains($0) }) else {
                break
            }

            end = beforeEnd
        }

        return String(token[start..<end])
    }

    private static func preservesLeadingRelativePathPrefix(
        in token: String,
        at index: String.Index,
    ) -> Bool {
        guard token[index] == "." else { return false }

        let nextIndex = token.index(after: index)
        guard nextIndex < token.endIndex else { return false }

        if token[nextIndex] == "/" {
            return true
        }

        let secondIndex = token.index(after: nextIndex)
        return token[nextIndex] == "."
            && secondIndex < token.endIndex
            && token[secondIndex] == "/"
    }

    // MARK: Rule Application

    private static func applyReplacementRule(
        _ rule: TextForSpeech.Replacement,
        to text: String,
        context: TextForSpeech.Context?,
        format: NormalizationFormat,
        nestedFormat: TextForSpeech.SourceFormat?,
    ) -> String {
        switch rule.match {
            case .exactPhrase:
                guard !rule.text.isEmpty else { return text }

                return text.replacingOccurrences(
                    of: rule.text,
                    with: resolvedReplacement(
                        for: rule.text,
                        rule: rule,
                        context: context,
                        format: format,
                        nestedFormat: nestedFormat,
                    ),
                    options: rule.isCaseSensitive ? [] : [.caseInsensitive],
                )

            case .wholeToken:
                guard !rule.text.isEmpty else { return text }

                return transformTokens(in: text) { token in
                    tokenMatches(rule.text, token: token, caseSensitive: rule.isCaseSensitive)
                        ? resolvedReplacement(
                            for: token,
                            rule: rule,
                            context: context,
                            format: format,
                            nestedFormat: nestedFormat,
                        )
                        : nil
                }

            case let .token(tokenKind):
                return transformTokens(in: text) { token in
                    tokenMatches(tokenKind, token: token)
                        ? resolvedReplacement(
                            for: token,
                            rule: rule,
                            context: context,
                            format: format,
                            nestedFormat: nestedFormat,
                        )
                        : nil
                }

            case let .line(lineKind):
                return transformLines(in: text) { line in
                    lineMatches(lineKind, line: line)
                        ? resolvedReplacement(
                            for: line,
                            rule: rule,
                            context: context,
                            format: format,
                            nestedFormat: nestedFormat,
                        )
                        : nil
                }
        }
    }

    private static func resolvedReplacement(
        for text: String,
        rule: TextForSpeech.Replacement,
        context: TextForSpeech.Context?,
        format: NormalizationFormat,
        nestedFormat: TextForSpeech.SourceFormat?,
    ) -> String {
        switch rule.transform {
            case let .literal(replacement):
                replacement

            case .spokenPath:
                spokenPath(text, context: context)

            case .spokenURL:
                spokenURL(text)

            case .spokenIdentifier:
                spokenIdentifier(text)

            case .spokenCode:
                switch format {
                    case let .source(sourceFormat):
                        spokenSource(text, format: sourceFormat)
                    case .text:
                        if let nestedFormat {
                            spokenSource(text, format: nestedFormat)
                        } else {
                            spokenCode(text)
                        }
                }

            case let .spokenFunctionCall(style):
                spokenFunctionCall(text, style: style)

            case let .spokenIssueReference(style):
                spokenIssueReference(text, style: style)

            case let .spokenFileReference(style):
                spokenFileReference(text, style: style)

            case let .spokenCLIFlag(style):
                spokenCLIFlag(text, style: style)

            case .spellOut:
                spelledOut(trimmedCandidateToken(text))
        }
    }
}
