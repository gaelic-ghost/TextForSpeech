import Foundation

// MARK: - Markdown Normalization Passes

extension TextNormalizer {
    // MARK: Markdown Code Normalization

    static func normalizeFencedCodeBlocks(
        _ text: String,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
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
                    output.append(spokenCodeBlock(body, nestedFormat: nestedFormat))
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
            output.append(spokenCodeBlock(bufferedCode.joined(separator: "\n"), nestedFormat: nestedFormat))
        }

        return output.joined(separator: "\n")
    }

    static func normalizeInlineCodeSpans(
        _ text: String,
        nestedFormat: TextForSpeech.SourceFormat? = nil,
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
                result += spokenInlineCode(body, nestedFormat: nestedFormat)
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
}
