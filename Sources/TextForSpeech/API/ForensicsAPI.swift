import Foundation

// MARK: - Forensics API

public extension TextForSpeech {
    enum Forensics {}
}

public extension TextForSpeech.Forensics {
    static func features(
        originalText: String,
        normalizedText: String
    ) -> TextForSpeech.ForensicFeatures {
        TextNormalizer.forensicFeatures(originalText: originalText, normalizedText: normalizedText)
    }

    static func sections(originalText: String) -> [TextForSpeech.Section] {
        TextNormalizer.sections(originalText: originalText)
    }

    static func sectionWindows(
        originalText: String,
        totalDurationMS: Int,
        totalChunkCount: Int
    ) -> [TextForSpeech.SectionWindow] {
        TextNormalizer.sectionWindows(
            originalText: originalText,
            totalDurationMS: totalDurationMS,
            totalChunkCount: totalChunkCount
        )
    }

    static func words(in text: String) -> [String] {
        TextNormalizer.naturalLanguageWords(in: text)
    }
}
