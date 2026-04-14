import SwiftUI

struct MainView: View {
    @State private var canvasState = CanvasState()
    @State private var chatState = ChatState()

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Canvas area (2/3 or full width)
                    ZStack(alignment: .bottom) {
                        InfiniteCanvasView(state: canvasState)

                        ChatInputBar(state: chatState) {
                            // Capture canvas drawing and attach to chat
                            chatState.attachCanvasSnapshot(canvasState.drawing)
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 12)
                    }
                    .frame(width: canvasWidth(in: geometry))

                    // Preview area (1/3, collapsible)
                    if canvasState.isPreviewVisible {
                        Divider()

                        PreviewPanel(canvasState: canvasState)
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
                        .foregroundStyle(.primary)
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    // API Key settings
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
}
