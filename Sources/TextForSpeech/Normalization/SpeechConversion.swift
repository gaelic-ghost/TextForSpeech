import Foundation

extension TextNormalizer {
    static func spokenCode(_ text: String) -> String {
        let replacements: [(String, String)] = [
            ("\n", ". "),
            ("->", " returns "),
            ("=>", " maps to "),
            ("===", " strictly equals "),
            ("!==", " not strictly equals "),
            ("==", " equals equals "),
            ("!=", " not equals "),
            ("&&", " and "),
            ("||", " or "),
            ("::", " double colon "),
            ("?.", " optional chaining "),
            ("??", " nil coalescing "),
            ("...", " ellipsis "),
            ("_", " "),
            ("#", " hash "),
            ("*", " star "),
            ("{", " open brace "),
            ("}", " close brace "),
            ("[", " open bracket "),
            ("]", " close bracket "),
            ("(", " open parenthesis "),
            (")", " close parenthesis "),
            ("<", " less than "),
            (">", " greater than "),
            ("/", " slash "),
            ("\\", " backslash "),
            (":", " colon "),
            (";", " semicolon "),
            ("=", " equals "),
        ]

        let spoken = replacements.reduce(text) { partial, replacement in
            partial.replacingOccurrences(of: replacement.0, with: replacement.1)
        }

        return collapseWhitespace(insertWordBreaks(in: spoken))
    }

    static func spokenPath(_ text: String, context: TextForSpeech.Context? = nil) -> String {
        let contextualPath = contextualizedPath(text, context: context)
        var segments: [String] = []
        var buffer = ""
        var remainder = contextualPath.path[...]

        if let spokenContextPrefix = contextualPath.spokenContextPrefix {
            segments.append(spokenContextPrefix)
        } else if let alias = aliasedPathPrefix(in: contextualPath.path) {
            segments.append(alias.spokenName)
            remainder = contextualPath.path[alias.range.upperBound...]
        }

        func flushBuffer() {
            guard !buffer.isEmpty else { return }

            segments.append(spokenSegment(buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        for character in remainder {
            switch character {
                case "~":
                    flushBuffer()
                    segments.append("home")
                case "/":
                    flushBuffer()
                case "\\":
                    flushBuffer()
                case ".":
                    flushBuffer()
                    segments.append("dot")
                case "_":
                    flushBuffer()
                    segments.append(" ")
                case "-":
                    flushBuffer()
                    segments.append(" ")
                default:
                    buffer.append(character)
            }
        }

        flushBuffer()
        return collapseWhitespace(segments.joined(separator: " "))
    }

    static func spokenURL(_ text: String) -> String {
        guard let schemeSeparator = text.range(of: "://") else {
            return spokenPath(text)
        }

        let scheme = text[..<schemeSeparator.lowerBound].lowercased()
        var remainder = String(text[schemeSeparator.upperBound...])

        if ["http", "https"].contains(scheme) {
            if remainder.lowercased().hasPrefix("www.") {
                remainder.removeFirst(4)
            }

            return spokenSlashSeparatedPath(remainder)
        }

        return collapseWhitespace(
            "\(spokenSegment(String(scheme))) colon slash slash \(spokenSlashSeparatedPath(remainder))",
        )
    }

    static func spokenIdentifier(_ text: String) -> String {
        var parts: [String] = []
        var buffer = ""

        func flushBuffer() {
            guard !buffer.isEmpty else { return }

            parts.append(spokenSegment(buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        for character in text {
            switch character {
                case ".":
                    flushBuffer()
                    parts.append("dot")
                case "_":
                    flushBuffer()
                    parts.append(" ")
                case "-":
                    flushBuffer()
                    parts.append(" ")
                default:
                    buffer.append(character)
            }
        }

        flushBuffer()
        return collapseWhitespace(parts.joined(separator: " "))
    }

    static func spokenFunctionCall(
        _ text: String,
        style: TextForSpeech.Replacement.Transform.FunctionCallStyle,
    ) -> String {
        guard text.hasSuffix("()") else { return spokenIdentifier(text) }

        let base = String(text.dropLast(2))
        let spokenBase = spokenIdentifier(base)

        switch style {
            case .compact:
                return spokenBase
            case .balanced:
                return "\(spokenBase) function"
            case .explicit:
                return "\(spokenBase) function call"
        }
    }

    static func spokenIssueReference(
        _ text: String,
        style: TextForSpeech.Replacement.Transform.IssueReferenceStyle,
    ) -> String {
        let digits = text.drop { $0 == "#" }
        let number = String(digits)

        switch style {
            case .compact:
                return number
            case .balanced:
                return "issue \(number)"
            case .explicit:
                return "issue number \(number)"
        }
    }

    static func spokenFileReference(
        _ text: String,
        style: TextForSpeech.Replacement.Transform.FileReferenceStyle,
        context: TextForSpeech.Context? = nil,
    ) -> String {
        let parts = text.split(separator: ":", omittingEmptySubsequences: false).map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return spokenPath(text, context: context) }

        let file = spokenPath(parts[0], context: context)
        let line = parts[1]
        let column = parts.count == 3 ? parts[2] : nil

        switch style {
            case .compact:
                if let column {
                    return "\(file) \(line) \(column)"
                }
                return "\(file) \(line)"
            case .balanced:
                if let column {
                    return "\(file) line \(line) column \(column)"
                }
                return "\(file) at line \(line)"
            case .explicit:
                if let column {
                    return "file \(file) line \(line) column \(column)"
                }
                return "file \(file) at line \(line)"
        }
    }

    static func spokenCLIFlag(
        _ text: String,
        style: TextForSpeech.Replacement.Transform.CLIFlagStyle,
    ) -> String {
        let isLongFlag = text.hasPrefix("--")
        let body = String(text.drop { $0 == "-" })
        let spokenBody = spokenSegment(body.replacingOccurrences(of: "-", with: " "))

        switch style {
            case .compact:
                return spokenBody
            case .balanced:
                return isLongFlag ? "dash dash \(spokenBody)" : "dash \(spokenBody)"
            case .explicit:
                return isLongFlag ? "long flag \(spokenBody)" : "short flag \(spokenBody)"
        }
    }

    private static func spokenSlashSeparatedPath(_ text: String) -> String {
        var segments: [String] = []
        var buffer = ""

        func flushBuffer() {
            guard !buffer.isEmpty else { return }

            segments.append(spokenSegment(buffer))
            buffer.removeAll(keepingCapacity: true)
        }

        for character in text {
            switch character {
                case "/":
                    flushBuffer()
                    if !segments.isEmpty {
                        segments.append("slash")
                    }
                case ".":
                    flushBuffer()
                    segments.append("dot")
                case "_", "-":
                    flushBuffer()
                default:
                    buffer.append(character)
            }
        }

        flushBuffer()
        return collapseWhitespace(segments.joined(separator: " "))
    }
}
