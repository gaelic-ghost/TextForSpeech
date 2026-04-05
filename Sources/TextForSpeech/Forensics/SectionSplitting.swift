// MARK: - Section Splitting

extension TextNormalizer {
    struct SectionCandidate {
        let title: String
        let kind: TextForSpeech.SectionKind
        let text: String
    }

    static func splitSections(in text: String) -> [SectionCandidate] {
        let headerSections = splitMarkdownHeaderSections(in: text)
        if !headerSections.isEmpty {
            return headerSections
        }

        let paragraphSections = splitParagraphSections(in: text)
        if !paragraphSections.isEmpty {
            return paragraphSections
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return [
            SectionCandidate(
                title: "Full Request",
                kind: .fullRequest,
                text: trimmed
            )
        ]
    }

    private static func splitMarkdownHeaderSections(in text: String) -> [SectionCandidate] {
        let lines = text.components(separatedBy: .newlines)
        var sections: [SectionCandidate] = []
        var currentTitle: String?
        var currentLines: [String] = []

        func flushCurrentSection() {
            guard let currentTitle else { return }
            let sectionText = currentLines.joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !sectionText.isEmpty else { return }
            sections.append(
                SectionCandidate(
                    title: currentTitle,
                    kind: .markdownHeader,
                    text: sectionText
                )
            )
        }

        for line in lines {
            if let title = markdownHeaderTitle(in: line) {
                flushCurrentSection()
                currentTitle = title
                currentLines = [line]
            } else if currentTitle != nil {
                currentLines.append(line)
            }
        }

        flushCurrentSection()
        return sections
    }

    private static func splitParagraphSections(in text: String) -> [SectionCandidate] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        return trimmed
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .enumerated()
            .map { index, paragraph in
                SectionCandidate(
                    title: "Paragraph \(index + 1)",
                    kind: .paragraph,
                    text: paragraph
                )
            }
    }

    static func markdownHeaderTitle(in line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.first == "#" else { return nil }

        let title = trimmed.drop(while: { $0 == "#" }).trimmingCharacters(in: .whitespaces)
        return title.isEmpty ? nil : title
    }
}
