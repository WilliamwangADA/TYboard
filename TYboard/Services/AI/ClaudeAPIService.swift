import Foundation
import UIKit

/// Claude API service with streaming support
actor ClaudeAPIService {
    static let shared = ClaudeAPIService()

    private let baseURL = "https://api.anthropic.com/v1/messages"
    private let apiVersion = "2023-06-01"
    private var apiKey: String {
        // Read from UserDefaults or Keychain in production
        UserDefaults.standard.string(forKey: "claude_api_key") ?? ""
    }

    struct Message: Codable {
        let role: String
        let content: [ContentBlock]
    }

    enum ContentBlock: Codable {
        case text(String)
        case image(mediaType: String, data: String)

        enum CodingKeys: String, CodingKey {
            case type, text, source
        }

        enum SourceKeys: String, CodingKey {
            case type, mediaType = "media_type", data
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .image(let mediaType, let data):
                try container.encode("image", forKey: .type)
                var source = container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
                try source.encode("base64", forKey: .type)
                try source.encode(mediaType, forKey: .mediaType)
                try source.encode(data, forKey: .data)
            }
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            let type = try container.decode(String.self, forKey: .type)
            if type == "text" {
                let text = try container.decode(String.self, forKey: .text)
                self = .text(text)
            } else {
                let source = try container.nestedContainer(keyedBy: SourceKeys.self, forKey: .source)
                let mediaType = try source.decode(String.self, forKey: .mediaType)
                let data = try source.decode(String.self, forKey: .data)
                self = .image(mediaType: mediaType, data: data)
            }
        }
    }

    struct APIRequest: Codable {
        let model: String
        let maxTokens: Int
        let system: String?
        let messages: [Message]
        let stream: Bool

        enum CodingKeys: String, CodingKey {
            case model
            case maxTokens = "max_tokens"
            case system, messages, stream
        }
    }

    // MARK: - Streaming response types

    struct StreamEvent {
        enum EventType {
            case contentBlockDelta(String)
            case messageStop
            case error(String)
        }
        let type: EventType
    }

    // MARK: - Send message with streaming

    func sendMessage(
        messages: [Message],
        systemPrompt: String? = nil,
        model: String = "claude-sonnet-4-20250514"
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let request = APIRequest(
                        model: model,
                        maxTokens: 4096,
                        system: systemPrompt,
                        messages: messages,
                        stream: true
                    )

                    var urlRequest = URLRequest(url: URL(string: baseURL)!)
                    urlRequest.httpMethod = "POST"
                    urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
                    urlRequest.setValue(apiVersion, forHTTPHeaderField: "anthropic-version")
                    urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")

                    let encoder = JSONEncoder()
                    urlRequest.httpBody = try encoder.encode(request)

                    let (bytes, response) = try await URLSession.shared.bytes(for: urlRequest)

                    guard let httpResponse = response as? HTTPURLResponse else {
                        continuation.finish(throwing: APIError.invalidResponse)
                        return
                    }

                    guard httpResponse.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines {
                            errorBody += line
                        }
                        continuation.finish(throwing: APIError.httpError(httpResponse.statusCode, errorBody))
                        return
                    }

                    // Parse SSE stream
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonStr = String(line.dropFirst(6))
                            if let data = jsonStr.data(using: .utf8),
                               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {

                                let type = json["type"] as? String

                                if type == "content_block_delta",
                                   let delta = json["delta"] as? [String: Any],
                                   let text = delta["text"] as? String {
                                    continuation.yield(text)
                                } else if type == "message_stop" {
                                    break
                                } else if type == "error",
                                          let error = json["error"] as? [String: Any],
                                          let message = error["message"] as? String {
                                    continuation.finish(throwing: APIError.apiError(message))
                                    return
                                }
                            }
                        }
                    }

                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }

    // MARK: - Non-streaming single response

    func sendMessageSync(
        messages: [Message],
        systemPrompt: String? = nil,
        model: String = "claude-sonnet-4-20250514"
    ) async throws -> String {
        var fullResponse = ""
        for try await chunk in sendMessage(messages: messages, systemPrompt: systemPrompt, model: model) {
            fullResponse += chunk
        }
        return fullResponse
    }

    // MARK: - Convenience: text-only message

    func chat(
        userText: String,
        history: [Message] = [],
        systemPrompt: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        var messages = history
        messages.append(Message(role: "user", content: [.text(userText)]))
        return sendMessage(messages: messages, systemPrompt: systemPrompt)
    }

    // MARK: - Convenience: text + image message

    func chatWithImage(
        userText: String,
        imageData: Data,
        history: [Message] = [],
        systemPrompt: String? = nil
    ) -> AsyncThrowingStream<String, Error> {
        let base64 = imageData.base64EncodedString()
        var messages = history
        messages.append(Message(role: "user", content: [
            .image(mediaType: "image/png", data: base64),
            .text(userText),
        ]))
        return sendMessage(messages: messages, systemPrompt: systemPrompt)
    }

    // MARK: - API Key management

    func setAPIKey(_ key: String) {
        UserDefaults.standard.set(key, forKey: "claude_api_key")
    }

    func hasAPIKey() -> Bool {
        !apiKey.isEmpty
    }

    enum APIError: LocalizedError {
        case invalidResponse
        case httpError(Int, String)
        case apiError(String)
        case noAPIKey

        var errorDescription: String? {
            switch self {
            case .invalidResponse: "Invalid response from server"
            case .httpError(let code, let body): "HTTP \(code): \(body)"
            case .apiError(let message): "API error: \(message)"
            case .noAPIKey: "No API key configured"
            }
        }
    }
}
