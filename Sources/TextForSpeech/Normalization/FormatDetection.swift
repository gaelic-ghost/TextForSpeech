import Foundation

extension TextNormalizer {
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
}
