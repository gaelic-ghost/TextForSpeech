import Foundation
import NaturalLanguage

extension TextNormalizer {
    // MARK: Link Parsing

    struct MarkdownLinkMatch {
        let fullRange: Range<String.Index>
        let label: String
        let destination: String
    }

    // MARK: Code Span Extraction

    static func fencedCodeBlockBodies(in text: String) -> [String] {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        var bodies: [String] = []
        var buffer: [String] = []
        var insideFence = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if insideFence {
                    bodies.append(buffer.joined(separator: "\n"))
                    buffer.removeAll(keepingCapacity: true)
                }
                insideFence.toggle()
                continue
            }

            if insideFence {
                buffer.append(line)
            }
        }

        if insideFence, !buffer.isEmpty {
            bodies.append(buffer.joined(separator: "\n"))
        }

        return bodies
    }

    static func inlineCodeBodies(in text: String) -> [String] {
        var bodies: [String] = []
        var index = text.startIndex

        while index < text.endIndex {
            guard text[index] == "`" else {
                index = text.index(after: index)
                continue
            }

            let contentStart = text.index(after: index)
            guard let closing = text[contentStart...].firstIndex(of: "`") else {
                break
            }

            bodies.append(String(text[contentStart..<closing]))
            index = text.index(after: closing)
        }

        return bodies
    }

    // MARK: Markdown Parsing

    static func markdownLinks(in text: String) -> [MarkdownLinkMatch] {
        var matches: [MarkdownLinkMatch] = []
        var cursor = text.startIndex

        while cursor < text.endIndex {
            guard let labelStart = text[cursor...].firstIndex(of: "[") else { break }
            guard let labelEnd = text[labelStart...].firstRange(of: "](")?.lowerBound else {
                cursor = text.index(after: labelStart)
                continue
            }

            let destinationStart = text.index(labelEnd, offsetBy: 2)
            guard let destinationEnd = text[destinationStart...].firstIndex(of: ")") else {
                cursor = text.index(after: labelStart)
                continue
            }

            let fullRange = labelStart..<text.index(after: destinationEnd)
            matches.append(
                MarkdownLinkMatch(
                    fullRange: fullRange,
                    label: String(text[text.index(after: labelStart)..<labelEnd]),
                    destination: String(text[destinationStart..<destinationEnd]),
                ),
            )
            cursor = fullRange.upperBound
        }

        return matches
    }

    // MARK: Token Candidates

    static func candidateTokens(in text: String) -> [String] {
        text
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .map(trimmedCandidateToken)
            .filter { !$0.isEmpty }
    }

    static func filePathFragments(in text: String) -> [String] {
        var fragments: [String] = []
        var index = text.startIndex

        while index < text.endIndex {
            let character = text[index]
            let startsTildePath = character == "~"
                && text.index(after: index) < text.endIndex
                && text[text.index(after: index)] == "/"

            guard character == "/" || startsTildePath else {
                index = text.index(after: index)
                continue
            }

            let start = index
            var end = index

            while end < text.endIndex {
                let current = text[end]
                if current.isWhitespace || "`),;\"[]{}".contains(current) {
                    break
                }
                end = text.index(after: end)
            }

            let fragment = String(text[start..<end])
            if isLikelyFilePath(fragment) {
                fragments.append(fragment)
            }

            index = end
        }

        return fragments
    }

    // MARK: Natural Language Tokens

    static func naturalLanguageWords(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).map { String(text[$0]) }
    }

    static func markdownHeaderTitle(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == "#" else { return nil }

        let title = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }
}
