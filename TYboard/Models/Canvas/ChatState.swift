import SwiftUI
import PencilKit

@Observable
final class ChatState {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isExpanded: Bool = false
    var isLoading: Bool = false
    var pendingImageData: Data?
    var showAPIKeyAlert: Bool = false
    var apiKeyInput: String = ""

    // Convert to API message format
    private var apiMessages: [ClaudeAPIService.Message] {
        messages.compactMap { msg in
            guard !msg.isStreaming else { return nil }
            var content: [ClaudeAPIService.ContentBlock] = []

            if let imageData = msg.imageData {
                content.append(.image(mediaType: "image/png", data: imageData.base64EncodedString()))
            }
            if !msg.content.isEmpty {
                content.append(.text(msg.content))
            }

            return ClaudeAPIService.Message(role: msg.role.rawValue, content: content)
        }
    }

    func attachCanvasSnapshot(_ drawing: PKDrawing) {
        pendingImageData = CanvasCapture.captureDrawing(drawing)
    }

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty || pendingImageData != nil else { return }

        let userMessage = ChatMessage(
            role: .user,
            content: text,
            imageData: pendingImageData
        )
        messages.append(userMessage)
        inputText = ""
        pendingImageData = nil
        isLoading = true

        // Add streaming placeholder
        let placeholderId = UUID()
        var streamingMessage = ChatMessage(role: .assistant, content: "", isStreaming: true)
        let streamingIndex = messages.count
        messages.append(streamingMessage)

        Task {
            do {
                let hasKey = await ClaudeAPIService.shared.hasAPIKey()
                guard hasKey else {
                    await MainActor.run {
                        messages.removeLast()
                        isLoading = false
                        showAPIKeyAlert = true
                    }
                    return
                }

                let stream = await ClaudeAPIService.shared.sendMessage(
                    messages: apiMessages,
                    systemPrompt: SystemPrompts.canvas
                )

                var fullText = ""
                for try await chunk in stream {
                    fullText += chunk
                    await MainActor.run {
                        if streamingIndex < messages.count {
                            messages[streamingIndex] = ChatMessage(
                                role: .assistant,
                                content: fullText,
                                isStreaming: true
                            )
                        }
                    }
                }

                await MainActor.run {
                    if streamingIndex < messages.count {
                        messages[streamingIndex] = ChatMessage(
                            role: .assistant,
                            content: fullText,
                            isStreaming: false
                        )
                    }
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    if streamingIndex < messages.count {
                        messages[streamingIndex] = ChatMessage(
                            role: .assistant,
                            content: "错误: \(error.localizedDescription)"
                        )
                    }
                    isLoading = false
                }
            }
        }
    }

    func setAPIKey(_ key: String) {
        Task {
            await ClaudeAPIService.shared.setAPIKey(key)
        }
    }
}
