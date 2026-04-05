import Foundation

// MARK: - Small Helpers

extension TextNormalizer {
    struct ContextualizedPath {
        let path: String
        let spokenContextPrefix: String?
    }

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
        format: TextForSpeech.Format,
        phase: TextForSpeech.Replacement.Phase
    ) -> String {
        profile.replacements(for: phase, in: format).reduce(text) { partial, rule in
            applyReplacementRule(rule, to: partial)
        }
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

    static func aliasedPathPrefix(in text: String) -> (range: Range<String.Index>, spokenName: String)? {
        let aliases = [
            ("/Users/galew", "gale wumbo"),
            ("/Users/galem", "gale mini"),
        ]

        for (prefix, spokenName) in aliases {
            guard text.hasPrefix(prefix) else { continue }

            let prefixEnd = text.index(text.startIndex, offsetBy: prefix.count)
            let isExactMatch = prefixEnd == text.endIndex
            let continuesAsPath = !isExactMatch && text[prefixEnd] == "/"
            if isExactMatch || continuesAsPath {
                return (text.startIndex..<prefixEnd, spokenName)
            }
        }

        return nil
    }

    static func standaloneGaleAlias(for token: String) -> String? {
        switch token.lowercased() {
        case "galew":
            "gale wumbo"
        case "galem":
            "gale mini"
        default:
            nil
        }
    }

    static func contextualizedPath(
        _ path: String,
        context: TextForSpeech.Context?
    ) -> ContextualizedPath {
        guard path.hasPrefix("/") else {
            return ContextualizedPath(path: path, spokenContextPrefix: nil)
        }

        let standardizedPath = NSString(string: path).standardizingPath

        if let cwd = context?.cwd,
            let relativePath = relativePath(from: cwd, to: standardizedPath)
        {
            let spokenContextPrefix = relativePath.isEmpty ? "current directory" : "current directory slash"
            return ContextualizedPath(path: relativePath, spokenContextPrefix: spokenContextPrefix)
        }

        if let repoRoot = context?.repoRoot,
            let relativePath = relativePath(from: repoRoot, to: standardizedPath)
        {
            let spokenContextPrefix = relativePath.isEmpty ? "repo root" : "repo root slash"
            return ContextualizedPath(path: relativePath, spokenContextPrefix: spokenContextPrefix)
        }

        return ContextualizedPath(path: standardizedPath, spokenContextPrefix: nil)
    }

    private static func relativePath(from basePath: String, to path: String) -> String? {
        let standardizedBasePath = NSString(string: basePath).standardizingPath

        guard standardizedPathBoundaryMatches(path, prefix: standardizedBasePath) else {
            return nil
        }

        guard path.count > standardizedBasePath.count else {
            return ""
        }

        let relativeStart = path.index(path.startIndex, offsetBy: standardizedBasePath.count + 1)
        return String(path[relativeStart...])
    }

    private static func standardizedPathBoundaryMatches(_ path: String, prefix: String) -> Bool {
        guard path.hasPrefix(prefix) else { return false }
        guard path.count > prefix.count else { return true }

        let boundaryIndex = path.index(path.startIndex, offsetBy: prefix.count)
        return path[boundaryIndex] == "/"
    }

    static func isLikelyFilePath(_ token: String) -> Bool {
        guard !token.isEmpty else { return false }
        guard !token.contains("://") else { return false }
        guard !token.contains("@") else { return false }

        return token.hasPrefix("/")
            || token.hasPrefix("~/")
            || (token.contains("/") && !token.contains(" "))
    }

    static func isLikelyURL(_ token: String) -> Bool {
        guard let schemeSeparator = token.range(of: "://") else { return false }
        let scheme = token[..<schemeSeparator.lowerBound]
        guard !scheme.isEmpty else { return false }
        return scheme.allSatisfy { $0.isLetter }
    }

    static func isLikelyDottedIdentifier(_ token: String) -> Bool {
        guard token.contains(".") else { return false }
        guard !isLikelyFilePath(token) else { return false }
        guard !token.contains("://") else { return false }

        let parts = token.split(separator: ".").map(String.init)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy(isIdentifierLike)
    }

    static func isLikelySnakeCaseIdentifier(_ token: String) -> Bool {
        guard token.contains("_") else { return false }
        let parts = token.split(separator: "_").map(String.init)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isAlphaNumeric) }
    }

    static func isLikelyDashedIdentifier(_ token: String) -> Bool {
        guard token.contains("-") else { return false }
        guard !isLikelyFilePath(token) else { return false }
        guard !token.contains("://") else { return false }

        let parts = token.split(separator: "-").map(String.init)
        guard parts.count >= 2 else { return false }
        return parts.allSatisfy { !$0.isEmpty && $0.allSatisfy(\.isAlphaNumeric) }
    }

    static func isLikelyCamelCaseIdentifier(_ token: String) -> Bool {
        guard !token.contains("."),
            !token.contains("_"),
            !token.contains("-"),
            !token.contains("/")
        else {
            return false
        }

        return hasLowerToUpperTransition(token)
    }

    static func isLikelyObjectiveCSymbol(_ token: String) -> Bool {
        if token.hasPrefix("NS"), token.dropFirst(2).first?.isUppercase == true {
            return true
        }

        guard token.contains(":") else { return false }
        return token.split(separator: ":").allSatisfy { part in
            !part.isEmpty && part.allSatisfy(\.isAlphaNumeric)
        }
    }

    static func isIdentifierLike(_ token: String) -> Bool {
        !token.isEmpty && token.allSatisfy { $0.isAlphaNumeric || $0 == "_" }
    }

    static func hasLowerToUpperTransition(_ text: String) -> Bool {
        var previous: Character?

        for character in text {
            defer { previous = character }
            guard let previous else { continue }
            if previous.isLowercase, character.isUppercase {
                return true
            }
        }

        return false
    }

    static func containsRepeatedLetterRun(_ text: String) -> Bool {
        var previous: Character?
        var runLength = 1

        for character in text.lowercased() {
            guard character.isLetter else {
                previous = nil
                runLength = 1
                continue
            }

            if previous == character {
                runLength += 1
                if runLength >= 3 {
                    return true
                }
            } else {
                previous = character
                runLength = 1
            }
        }

        return false
    }

    static func spelledOut(_ text: String) -> String {
        text.map { String($0) }.joined(separator: " ")
    }

    static func spokenCodeBlock(_ body: String) -> String {
        let spoken = spokenCode(body)
        return spoken.isEmpty ? "Code sample." : "Code sample. \(spoken). End code sample."
    }

    static func spokenInlineCode(_ body: String) -> String {
        let spoken = spokenCode(body)
        return spoken.isEmpty ? " code " : " \(spoken) "
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

    static func isLikelyCodeLine(_ line: String) -> Bool {
        let punctuation = line.filter { "{}[]()<>/\\=_*#|~:;.`-".contains($0) }.count
        let letters = line.filter(\.isLetter).count
        let hasStructuredMarker =
            line.firstMatch(of: codeMarkerRegex) != nil
            || line.contains("[")
            || line.contains("]")
            || line.contains("@property")

        return punctuation >= 6 && (punctuation * 2 >= max(letters, 4) || hasStructuredMarker)
    }
}

extension Character {
    fileprivate var isAlphaNumeric: Bool { isLetter || isNumber }
}
