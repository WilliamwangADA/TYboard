import SwiftUI

@Observable
final class ChatState {
    var messages: [ChatMessage] = []
    var inputText: String = ""
    var isExpanded: Bool = false

    func sendMessage() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        let userMessage = ChatMessage(role: .user, content: text)
        messages.append(userMessage)
        inputText = ""

        // TODO: Phase 2 - Send to Claude API and get response
        let placeholder = ChatMessage(role: .assistant, content: "AI功能将在Phase 2中接入")
        messages.append(placeholder)
    }
}
