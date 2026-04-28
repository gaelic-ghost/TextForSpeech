import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

enum TextSummarizer {
    static func summarize(
        _ text: String,
        provider: TextForSpeech.SummarizationProvider,
    ) async throws -> String {
        let prompt = summaryPrompt(for: text)

        return switch provider {
            case .codexExec:
                try await summarizeWithCodexExec(prompt: prompt)
            case .openAIResponses:
                try await summarizeWithOpenAIResponses(prompt: prompt)
            case .foundationModels:
                try await summarizeWithFoundationModels(prompt: prompt)
        }
    }

    private static func summaryPrompt(for text: String) -> String {
        """
        Summarize the following text for text-to-speech playback.

        Requirements:
        - Keep the important technical facts, names, paths, commands, and decisions.
        - Remove repetition, incidental phrasing, and low-value filler.
        - Use plain, speakable prose.
        - Return only the summary text.

        Text:
        \(text)
        """
    }
}

extension TextSummarizer {
    private static func summarizeWithCodexExec(prompt: String) async throws -> String {
#if os(macOS)
        try await Task.detached {
            try runCodexExec(prompt: prompt)
        }
        .value
#else
        throw TextForSpeech.SummaryError.providerUnavailable(
            "TextForSpeech could not summarize with codex exec because Process-based CLI execution is only supported by this package on macOS.",
        )
#endif
    }

#if os(macOS)
    private static func runCodexExec(prompt: String) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [
            "codex",
            "exec",
            "--ephemeral",
            "--sandbox",
            "read-only",
            "-",
        ]

        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error

        do {
            try process.run()
        } catch {
            throw TextForSpeech.SummaryError.providerUnavailable(
                "TextForSpeech could not start codex exec for summarization. Confirm the Codex CLI is installed and available on PATH. \(error.localizedDescription)",
            )
        }

        input.fileHandleForWriting.write(Data(prompt.utf8))
        try? input.fileHandleForWriting.close()
        process.waitUntilExit()

        let outputText = String(decoding: output.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errorText = String(decoding: error.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw TextForSpeech.SummaryError.providerFailed(
                "TextForSpeech could not summarize with codex exec because the CLI exited with status \(process.terminationStatus). \(errorText)",
            )
        }

        return outputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
#endif
}

extension TextSummarizer {
    private struct OpenAIRequest: Encodable {
        let model: String
        let input: String
        let store: Bool
        let maxOutputTokens: Int

        enum CodingKeys: String, CodingKey {
            case model
            case input
            case store
            case maxOutputTokens = "max_output_tokens"
        }
    }

    private struct OpenAIResponse: Decodable {
        let output: [OutputItem]

        struct OutputItem: Decodable {
            let content: [ContentItem]?
        }

        struct ContentItem: Decodable {
            let type: String
            let text: String?
        }
    }

    private static func summarizeWithOpenAIResponses(prompt: String) async throws -> String {
        guard let apiKey = ProcessInfo.processInfo.environment["OPENAI_API_KEY"], !apiKey.isEmpty else {
            throw TextForSpeech.SummaryError.missingCredential(
                "TextForSpeech could not summarize with the OpenAI Responses API because OPENAI_API_KEY is not present in the process environment.",
            )
        }

        let model = ProcessInfo.processInfo.environment["TEXT_FOR_SPEECH_OPENAI_SUMMARY_MODEL"] ?? "gpt-5.4-mini"
        guard let url = URL(string: "https://api.openai.com/v1/responses") else {
            throw TextForSpeech.SummaryError.providerFailed(
                "TextForSpeech could not summarize with the OpenAI Responses API because the responses endpoint URL is invalid.",
            )
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONEncoder().encode(
            OpenAIRequest(
                model: model,
                input: prompt,
                store: false,
                maxOutputTokens: 500,
            ),
        )

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw TextForSpeech.SummaryError.providerFailed(
                "TextForSpeech could not summarize with the OpenAI Responses API because the network request failed. \(error.localizedDescription)",
            )
        }

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TextForSpeech.SummaryError.providerFailed(
                "TextForSpeech could not summarize with the OpenAI Responses API because the response was not an HTTP response.",
            )
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let details = String(decoding: data.prefix(1000), as: UTF8.self)
            throw TextForSpeech.SummaryError.providerFailed(
                "TextForSpeech could not summarize with the OpenAI Responses API because the service returned HTTP \(httpResponse.statusCode). \(details)",
            )
        }

        do {
            let decoded = try JSONDecoder().decode(OpenAIResponse.self, from: data)
            if let text = decoded.output
                .flatMap({ $0.content ?? [] })
                .first(where: { $0.type == "output_text" })?
                .text?
                .trimmingCharacters(in: .whitespacesAndNewlines),
                !text.isEmpty {
                return text
            }
        } catch {
            throw TextForSpeech.SummaryError.providerFailed(
                "TextForSpeech could not decode the OpenAI Responses API summary response. \(error.localizedDescription)",
            )
        }

        throw TextForSpeech.SummaryError.providerFailed(
            "TextForSpeech could not summarize with the OpenAI Responses API because the response did not contain output text.",
        )
    }
}

extension TextSummarizer {
    private static func summarizeWithFoundationModels(prompt: String) async throws -> String {
#if canImport(FoundationModels)
        if #available(macOS 26.0, iOS 26.0, *) {
            let session = LanguageModelSession(
                instructions: "Summarize text for text-to-speech playback. Return only concise, speakable prose.",
            )
            let response = try await session.respond(to: prompt)
            return response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        }
#endif

        throw TextForSpeech.SummaryError.providerUnavailable(
            "TextForSpeech could not summarize with Foundation Models because Apple's FoundationModels framework is not available in this build or on this operating system.",
        )
    }
}
