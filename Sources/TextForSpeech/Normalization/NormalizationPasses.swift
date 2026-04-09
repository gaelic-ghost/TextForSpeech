import Foundation

// MARK: - Normalization Passes

extension TextNormalizer {
    // MARK: Source Line Normalization

    static func normalizeStructuredSourceLines(
        _ text: String,
        format: TextForSpeech.SourceFormat
    ) -> String {
        applySingleBaseRule(
            id: "base-source-line",
            to: text,
            format: .source(format)
        )
    }

    // MARK: Markdown Code Normalization

    static func normalizeFencedCodeBlocks(
        _ text: String,
        nestedFormat: TextForSpeech.SourceFormat? = nil
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
        nestedFormat: TextForSpeech.SourceFormat? = nil
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

    // MARK: Token-Level Passes

    static func normalizeURLs(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-url",
            to: text,
            format: .text(.plain)
        )
    }

    static func normalizeStandaloneGaleAliases(_ text: String) -> String {
        applyReplacementRules(
            text,
            profile: TextForSpeech.Profile(
                id: "base-aliases-only",
                name: "Base Aliases Only",
                replacements: [
                    TextForSpeech.Profile.base.replacement(id: "base-galew"),
                    TextForSpeech.Profile.base.replacement(id: "base-galem"),
                ].compactMap { $0 }
            ),
            format: .text(.plain),
            phase: .beforeBuiltIns
        )
    }

    static func normalizeFilePaths(
        _ text: String,
        context: TextForSpeech.Context? = nil,
        profile _: TextForSpeech.Profile = .default,
        format _: NormalizationFormat = .text(.plain),
        nestedFormat _: TextForSpeech.SourceFormat? = nil
    ) -> String {
        applySingleBaseRule(
            id: "base-file-path",
            to: text,
            format: .text(.plain),
            context: context
        )
    }

    static func normalizeDottedIdentifiers(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-dotted-identifier",
            to: text,
            format: .text(.plain)
        )
    }

    static func normalizeSnakeCaseIdentifiers(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-snake-identifier",
            to: text,
            format: .text(.plain)
        )
    }

    static func normalizeDashedIdentifiers(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-dashed-identifier",
            to: text,
            format: .text(.plain)
        )
    }

    static func normalizeCamelCaseIdentifiers(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-camel-identifier",
            to: text,
            format: .text(.plain)
        )
    }

    // MARK: Code-Like Line Passes

    static func normalizeCodeHeavyLines(
        _ text: String,
        format: NormalizationFormat,
        nestedFormat: TextForSpeech.SourceFormat? = nil
    ) -> String {
        let ruleID: String = switch format {
        case .text:
            "base-text-code-line"
        case .source:
            "base-source-line"
        }

        return applySingleBaseRule(
            id: ruleID,
            to: text,
            format: format,
            nestedFormat: nestedFormat
        )
    }

    // MARK: Natural Language Passes

    static func normalizeSpiralProneWords(_ text: String) -> String {
        applySingleBaseRule(
            id: "base-repeated-letter-run",
            to: text,
            format: .text(.plain)
        )
    }

    // MARK: Format Heuristics

    static func looksLikeHTML(_ text: String) -> Bool {
        text.contains(/<([A-Za-z][A-Za-z0-9:-]*)(\s[^>]*)?>/) && text.contains("</")
    }

    static func looksLikeMarkdownList(_ text: String) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let listLineCount = lines.count { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("- ")
                || trimmed.hasPrefix("* ")
                || trimmed.hasPrefix("+ ")
                || trimmed.firstMatch(of: /^\d+\.\s+/) != nil
        }

        return listLineCount >= 2
    }

    static func looksLikeMarkdown(_ text: String) -> Bool {
        text.contains("```")
            || text.split(separator: "\n", omittingEmptySubsequences: false)
                .contains(where: { markdownHeaderTitle(in: String($0)) != nil })
            || !markdownLinks(in: text).isEmpty
            || !inlineCodeBodies(in: text).isEmpty
    }

    static func looksLikeSwiftSource(_ text: String) -> Bool {
        text.contains("import Foundation")
            || text.contains("import SwiftUI")
            || text.contains("func ")
            || text.contains("struct ")
            || text.contains("enum ")
            || text.contains("actor ")
            || text.contains("let ")
    }

    static func looksLikePythonSource(_ text: String) -> Bool {
        text.contains("def ")
            || text.contains("import ")
            || text.contains("from ")
            || text.contains("self.")
            || text.contains("print(")
    }

    static func looksLikeRustSource(_ text: String) -> Bool {
        text.contains("fn ")
            || text.contains("let mut ")
            || text.contains("impl ")
            || text.contains("use ")
            || text.contains("pub struct ")
    }

    static func looksLikeCLIOutput(_ text: String) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let promptLikeLines = lines.count { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.hasPrefix("$ ")
                || trimmed.hasPrefix("> ")
                || trimmed.hasPrefix("% ")
                || trimmed.firstMatch(of: /^[A-Za-z0-9_.-]+@\S+[:~]/) != nil
        }

        return promptLikeLines >= 1
    }

    static func looksLikeLogOutput(_ text: String) -> Bool {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        let logLineCount = lines.count { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            return trimmed.firstMatch(of: /^\d{4}-\d{2}-\d{2}[ T]/) != nil
                || trimmed.contains(" ERROR ")
                || trimmed.contains(" WARN ")
                || trimmed.contains(" INFO ")
                || trimmed.contains("[error]")
                || trimmed.contains("[warn]")
                || trimmed.contains("[info]")
        }

        return logLineCount >= 1
    }

    private static func applySingleBaseRule(
        id: String,
        to text: String,
        format: NormalizationFormat,
        context: TextForSpeech.Context? = nil,
        nestedFormat: TextForSpeech.SourceFormat? = nil
    ) -> String {
        guard let rule = TextForSpeech.Profile.base.replacement(id: id) else { return text }

        return applyReplacementRules(
            text,
            profile: TextForSpeech.Profile(
                id: "base-\(id)",
                name: "Base \(id)",
                replacements: [rule]
            ),
            format: format,
            phase: .beforeBuiltIns,
            context: context,
            nestedFormat: nestedFormat
        )
    }
}
