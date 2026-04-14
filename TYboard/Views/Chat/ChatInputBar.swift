import SwiftUI

struct ChatInputBar: View {
    @Bindable var state: ChatState
    var onCaptureCanvas: (() -> Void)?

    @State private var speechRecognizer = SpeechRecognizer()
    @State private var showPhotoPicker = false

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
                            withAnimation {
                                proxy.scrollTo(last.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }

            // Pending image preview
            if state.pendingImageData != nil {
                HStack {
                    Image(systemName: "photo.fill")
                        .foregroundStyle(.blue)
                    Text("已附加画布截图")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        state.pendingImageData = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 14)
                .padding(.top, 6)
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

                // Canvas capture button
                Button {
                    onCaptureCanvas?()
                } label: {
                    Image(systemName: "camera.viewfinder")
                        .font(.title3)
                        .foregroundStyle(state.pendingImageData != nil ? .blue : .secondary)
                }

                // Attachment button
                Button {
                    showPhotoPicker = true
                } label: {
                    Image(systemName: "plus.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .photosPicker(
                    isPresented: $showPhotoPicker,
                    selection: .constant(nil),
                    matching: .images
                )

                // Text input
                TextField("描述你想要创建的内容...", text: $state.inputText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...5)
                    .onSubmit {
                        state.sendMessage()
                    }

                // Voice input button
                Button {
                    if speechRecognizer.isRecording {
                        speechRecognizer.stopRecording()
                        if !speechRecognizer.transcript.isEmpty {
                            state.inputText += speechRecognizer.transcript
                        }
                    } else {
                        speechRecognizer.startRecording()
                    }
                } label: {
                    Image(systemName: speechRecognizer.isRecording ? "mic.fill" : "mic.circle")
                        .font(.title3)
                        .foregroundStyle(speechRecognizer.isRecording ? .red : .secondary)
                        .symbolEffect(.pulse, isActive: speechRecognizer.isRecording)
                }

                // Send button
                Button {
                    state.sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(canSend ? Color.accentColor : .secondary)
                }
                .disabled(!canSend || state.isLoading)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.1), radius: 8, y: 2)
    }

    private var canSend: Bool {
        !state.inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        || state.pendingImageData != nil
    }
}

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 60) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 4) {
                // Image attachment indicator
                if message.imageData != nil {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                        Text("附件图片")
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

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

                if message.isStreaming {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            if message.role == .assistant { Spacer(minLength: 60) }
        }
    }
}
