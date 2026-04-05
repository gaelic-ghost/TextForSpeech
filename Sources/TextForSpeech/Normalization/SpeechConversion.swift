import Foundation

// MARK: - Speech Conversion

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
                if !segments.isEmpty {
                    segments.append("slash")
                }
            case "\\":
                flushBuffer()
                segments.append("backslash")
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
            if remainder.hasPrefix("www.") {
                remainder.removeFirst(4)
            }

            return spokenPath(remainder)
        }

        return collapseWhitespace(
            "\(spokenSegment(String(scheme))) colon slash slash \(spokenPath(remainder))"
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
}
