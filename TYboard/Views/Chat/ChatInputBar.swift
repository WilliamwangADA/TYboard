import SwiftUI

struct ChatInputBar: View {
    @Bindable var state: ChatState

    var body: some View {
        VStack(spacing: 0) {
            // Expandable message history
            if state.isExpanded {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(state.messages) { message in
                                MessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(12)
                    }
                    .frame(maxHeight: 300)
                    .onChange(of: state.messages.count) {
                        if let last = state.messages.last {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Input area
            HStack(spacing: 10) {
                // Expand/collapse chat history
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        state.isExpanded.toggle()
                    }
                } label: {
                    Image(systemName: state.isExpanded ? "chevron.down.circle.fill" : "chevron.up.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Attachment button
                Button {
                    // TODO: Phase 2 - File/image picker
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Text input
                TextField("描述你想要创建的内容...", text: $state.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit {
                        state.sendMessage()
                    }

                // Voice input button
                Button {
                    // TODO: Phase 2 - Voice input
                } label: {
                    Image(systemName: "mic.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                // Send button
                Button {
                    state.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(
                            state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                            ? Color.secondary
                            : Color.accentColor
                        )
                }
                .disabled(state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            Text(message.content)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    message.role == .user
                    ? Color.accentColor.opacity(0.15)
                    : Color.secondary.opacity(0.1),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(.primary)
                .font(.body)

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}
