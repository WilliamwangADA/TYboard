import SwiftUI

struct MainView: View {
    @State private var canvasState = CanvasState()
    @State private var chatState = ChatState()
    @State private var generationEngine = GenerationEngine()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Canvas area
                    ZStack(alignment: .bottom) {
                        InfiniteCanvasView(state: canvasState)

                        ChatInputBar(state: chatState) {
                            chatState.attachCanvasSnapshot(canvasState.drawing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .frame(width: canvasWidth(in: geometry))

                    // Preview area
                    if canvasState.isPreviewVisible {
                        Divider()

                        PreviewPanel(
                            canvasState: canvasState,
                            generationEngine: generationEngine
                        )
                        .frame(width: previewWidth(in: geometry))
                        .transition(.move(edge: .trailing))
                    }
                }
            }
            .ignoresSafeArea(.keyboard)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Text("TYboard")
                        .font(.headline)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Generate button
                    Button {
                        triggerGeneration()
                    } label: {
                        Label("生成", systemImage: "wand.and.stars")
                    }
                    .disabled(generationEngine.isGenerating)

                    Button {
                        chatState.showAPIKeyAlert = true
                    } label: {
                        Image(systemName: "key")
                    }

                    Button {
                        canvasState.togglePreview()
                    } label: {
                        Image(systemName: "sidebar.right")
                            .symbolVariant(canvasState.isPreviewVisible ? .none : .slash)
                    }

                    Button {
                        canvasState.resetView()
                    } label: {
                        Image(systemName: "arrow.counterclockwise")
                    }
                }
            }
            .alert("设置API Key", isPresented: $chatState.showAPIKeyAlert) {
                TextField("sk-ant-...", text: $chatState.apiKeyInput)
                Button("保存") {
                    chatState.setAPIKey(chatState.apiKeyInput)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("请输入你的Claude API Key")
            }
            // Auto-detect generated code in chat responses
            .onChange(of: chatState.messages.count) {
                checkForGeneratedCode()
            }
        }
    }

    private func canvasWidth(in geometry: GeometryProxy) -> CGFloat {
        if canvasState.isPreviewVisible {
            return geometry.size.width * (1 - canvasState.previewWidthRatio)
        }
        return geometry.size.width
    }

    private func previewWidth(in geometry: GeometryProxy) -> CGFloat {
        geometry.size.width * canvasState.previewWidthRatio
    }

    /// Trigger generation from current canvas + latest chat
    private func triggerGeneration() {
        let latestPrompt = chatState.messages
            .last(where: { $0.role == .user })?.content ?? ""

        Task {
            await generationEngine.generate(
                description: latestPrompt,
                drawing: canvasState.drawing,
                previousHTML: generationEngine.generatedHTML
            )
            // Auto-show preview
            if !canvasState.isPreviewVisible {
                canvasState.togglePreview()
            }
        }
    }

    /// Check if the latest AI response contains HTML code
    private func checkForGeneratedCode() {
        guard let lastMessage = chatState.messages.last,
              lastMessage.role == .assistant,
              !lastMessage.isStreaming else { return }

        if let html = CodeExtractor.extractHTML(from: lastMessage.content) {
            generationEngine.generatedHTML = html
            generationEngine.currentVersion += 1
            generationEngine.generationHistory.append(
                GenerationEngine.GenerationSnapshot(
                    version: generationEngine.currentVersion,
                    html: html,
                    prompt: chatState.messages.last(where: { $0.role == .user })?.content ?? "",
                    timestamp: Date()
                )
            )

            if !canvasState.isPreviewVisible {
                canvasState.togglePreview()
            }
        }
    }
}
