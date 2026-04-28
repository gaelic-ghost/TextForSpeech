import Foundation

extension TextNormalizer {
    private struct ParsedListItem {
        let content: Substring
    }

    // MARK: Markdown Code Normalization

    static func normalizePriorityListItems(_ text: String) -> String {
        transformLines(in: text) { line in
            guard let item = priorityListItem(in: line) else { return nil }

            let spokenPriority = spokenPriorityLevel(item.level)
            let remainder = item.remainder.trimmingCharacters(in: .whitespaces)

            if remainder.isEmpty {
                return spokenPriority
            }

            return "\(spokenPriority). \(remainder)"
        }
    }

    static func normalizeFencedCodeBlocks(
        _ text: String,
        context: TextForSpeech.InputContext? = nil,
        requestContext: TextForSpeech.RequestContext? = nil,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
        profile: TextForSpeech.Profile = .base,
    ) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard !lines.isEmpty else { return text }

        var output: [String] = []
        var bufferedCode: [String] = []
        var insideFence = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                if insideFence {
                    let body = bufferedCode.joined(separator: "\n")
                    output.append(
                        spokenCodeBlock(
                            body,
                            nestedFormat: nestedFormat,
                            context: context,
                            requestContext: requestContext,
                            profile: profile,
                        ),
                    )
                    bufferedCode.removeAll(keepingCapacity: true)
                }
                insideFence.toggle()
                continue
            }

            if insideFence {
                bufferedCode.append(line)
            } else {
                output.append(line)
            }
        }

        if insideFence, !bufferedCode.isEmpty {
            output.append(
                spokenCodeBlock(
                    bufferedCode.joined(separator: "\n"),
                    nestedFormat: nestedFormat,
                    context: context,
                    requestContext: requestContext,
                    profile: profile,
                ),
            )
        }

        return output.joined(separator: "\n")
    }

    static func normalizeInlineCodeSpans(
        _ text: String,
        context: TextForSpeech.InputContext? = nil,
        requestContext: TextForSpeech.RequestContext? = nil,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
        profile: TextForSpeech.Profile = .base,
    ) -> String {
        let bodies = inlineCodeBodies(in: text)
        guard !bodies.isEmpty else { return text }

        var result = ""
        var index = text.startIndex
        var bodyIterator = bodies.makeIterator()
        var nextBody = bodyIterator.next()

        while index < text.endIndex {
            guard text[index] == "`", let expectedBody = nextBody else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }

            let contentStart = text.index(after: index)
            guard let closing = text[contentStart...].firstIndex(of: "`") else {
                result.append(text[index])
                index = text.index(after: index)
                continue
            }

            let body = String(text[contentStart..<closing])
            if body == expectedBody {
                result += spokenInlineCode(
                    body,
                    nestedFormat: nestedFormat,
                    context: context,
                    requestContext: requestContext,
                    profile: profile,
                )
                index = text.index(after: closing)
                nextBody = bodyIterator.next()
            } else {
                result.append(text[index])
                index = text.index(after: index)
            }
        }

        return result
    }

    static func normalizeMarkdownLinks(_ text: String) -> String {
        let links = markdownLinks(in: text)
        guard !links.isEmpty else { return text }

        var result = ""
        var cursor = text.startIndex

        for link in links {
            result += text[cursor..<link.fullRange.lowerBound]
            let label = link.label.trimmingCharacters(in: .whitespacesAndNewlines)
            let destination = link.destination.trimmingCharacters(in: .whitespacesAndNewlines)

            if label.isEmpty {
                result += " \(destination) "
            } else {
                result += " \(label), link \(destination) "
            }

            cursor = link.fullRange.upperBound
        }

        result += text[cursor...]
        return result
    }

    // MARK: Priority List Parsing

    private static func priorityListItem(in line: String) -> (level: Int, remainder: String)? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        let content = parsedListItem(in: trimmed)?.content ?? trimmed[trimmed.startIndex...]
        guard let labelEnd = content.firstIndex(of: "]") else { return nil }
        guard content.first == "[" else { return nil }

        let labelBody = content[content.index(after: content.startIndex)..<labelEnd]
        guard let first = labelBody.first, first == "P" || first == "p" else { return nil }

        let digits = labelBody.dropFirst()
        guard !digits.isEmpty, digits.allSatisfy(\.isNumber), let level = Int(digits) else {
            return nil
        }

        let remainderStart = content.index(after: labelEnd)
        let remainder = trimmedPriorityRemainder(content[remainderStart...])
        return (level, remainder)
    }

    private static func parsedListItem(in line: String) -> ParsedListItem? {
        if let bulletContent = bulletListItemContent(in: line) {
            return ParsedListItem(content: bulletContent)
        }

        if let numberedContent = numberedListItemContent(in: line) {
            return ParsedListItem(content: numberedContent)
        }

        guard line.first == "[" else { return nil }

        return ParsedListItem(content: line[line.startIndex...])
    }

    private static func bulletListItemContent(in line: String) -> Substring? {
        guard let first = line.first, "-*+".contains(first) else { return nil }

        let afterMarker = line.index(after: line.startIndex)
        guard afterMarker < line.endIndex, line[afterMarker].isWhitespace else { return nil }

        var content = line[afterMarker...].drop(while: \.isWhitespace)
        content = content[taskListMarkerEnd(in: content)...]
        return content
    }

    private static func numberedListItemContent(in line: String) -> Substring? {
        var index = line.startIndex
        while index < line.endIndex, line[index].isNumber {
            index = line.index(after: index)
        }

        guard index > line.startIndex, index < line.endIndex, line[index] == "." else {
            return nil
        }

        let afterDot = line.index(after: index)
        guard afterDot < line.endIndex, line[afterDot].isWhitespace else { return nil }

        return line[afterDot...].drop(while: \.isWhitespace)
    }

    private static func taskListMarkerEnd(in content: Substring) -> Substring.Index {
        guard content.count >= 3 else { return content.startIndex }
        guard content.first == "[" else { return content.startIndex }

        let second = content.index(after: content.startIndex)
        let third = content.index(after: second)

        guard third < content.endIndex, content[third] == "]" else {
            return content.startIndex
        }

        let marker = content[second]
        guard marker == " " || marker == "x" || marker == "X" else {
            return content.startIndex
        }

        let afterMarker = content.index(after: third)
        guard afterMarker < content.endIndex, content[afterMarker].isWhitespace else {
            return content.startIndex
        }

        return content[afterMarker...].drop(while: \.isWhitespace).startIndex
    }

    private static func trimmedPriorityRemainder(_ remainder: Substring) -> String {
        var normalized = remainder.drop(while: \.isWhitespace)

        if let first = normalized.first, ":.-".contains(first) {
            normalized = normalized.dropFirst()
        }

        return String(normalized).trimmingCharacters(in: .whitespaces)
    }

    private static func spokenPriorityLevel(_ level: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .spellOut
        formatter.locale = Locale(identifier: "en_US_POSIX")

        let spokenLevel = formatter.string(from: NSNumber(value: level))?
            .capitalized ?? String(level)

        return "Priority Level \(spokenLevel)"
    }
}
