import SwiftUI

enum PreviewMode: String, CaseIterable {
    case web = "Web应用"
    case ppt = "PPT"
}

struct MainView: View {
    @State private var canvasState = CanvasState()
    @State private var chatState = ChatState()
    @State private var generationEngine = GenerationEngine()
    @State private var pptGenerator = PPTGenerator()
    @State private var assetStore = AssetStore()
    @State private var snapshotManager = SnapshotManager()
    @State private var habitTracker = UserHabitTracker()
    @State private var previewMode: PreviewMode = .web
    @State private var showAssetLibrary = false
    @State private var showTemplatePicker = false

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Canvas area
                    ZStack {
                        InfiniteCanvasView(state: canvasState)

                        VStack {
                            // Drawing toolbar at top
                            DrawingToolBar(
                                selectedTool: $canvasState.selectedTool,
                                selectedColor: $canvasState.selectedColor,
                                lineWidth: $canvasState.lineWidth
                            )
                            .padding(.top, 8)

                            Spacer()

                            // Chat input at bottom
                            ChatInputBar(state: chatState) {
                                chatState.attachCanvasSnapshot(canvasState.drawing)
                            }
                            .padding(.horizontal, 16)
                            .padding(.bottom, 12)
                        }
                    }
                    .frame(width: canvasWidth(in: geometry))

                    // Preview area
                    if canvasState.isPreviewVisible {
                        Divider()

                        VStack(spacing: 0) {
                            // Mode selector
                            Picker("", selection: $previewMode) {
                                ForEach(PreviewMode.allCases, id: \.self) { mode in
                                    Text(mode.rawValue).tag(mode)
                                }
                            }
                            .pickerStyle(.segmented)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)

                            switch previewMode {
                            case .web:
                                PreviewPanel(
                                    canvasState: canvasState,
                                    generationEngine: generationEngine
                                )
                            case .ppt:
                                PPTPreviewPanel(generator: pptGenerator)
                            }
                        }
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

                    // Template picker
                    Button {
                        showTemplatePicker = true
                    } label: {
                        Image(systemName: "doc.badge.plus")
                    }

                    // Snapshot
                    Button {
                        snapshotManager.takeSnapshot(
                            name: "快照 \(Date().formatted(.dateTime.hour().minute()))",
                            drawing: canvasState.drawing,
                            generatedHTML: generationEngine.generatedHTML,
                            chatSummary: chatState.messages.suffix(3).map(\.content).joined(separator: "\n")
                        )
                    } label: {
                        Image(systemName: "camera.circle")
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    // Generate Web
                    Button {
                        previewMode = .web
                        triggerWebGeneration()
                    } label: {
                        Label("生成Web", systemImage: "wand.and.stars")
                    }
                    .disabled(generationEngine.isGenerating)

                    // Generate PPT
                    Button {
                        previewMode = .ppt
                        triggerPPTGeneration()
                    } label: {
                        Label("生成PPT", systemImage: "rectangle.on.rectangle.angled")
                    }
                    .disabled(pptGenerator.isGenerating)

                    // Asset library
                    Button {
                        showAssetLibrary.toggle()
                    } label: {
                        Image(systemName: "tray.2")
                    }

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
            .onChange(of: chatState.messages.count) {
                checkForGeneratedCode()
            }
            .sheet(isPresented: $showAssetLibrary) {
                NavigationStack {
                    AssetLibraryView(store: assetStore) { asset in
                        // Send asset to chat as context
                        if let imageData = assetStore.imageData(for: asset) {
                            chatState.pendingImageData = imageData
                        }
                        showAssetLibrary = false
                    }
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("完成") { showAssetLibrary = false }
                        }
                    }
                }
            }
            .sheet(isPresented: $showTemplatePicker) {
                TemplatePickerView { template in
                    chatState.inputText = template.defaultPrompt
                    if template.category == .ppt {
                        previewMode = .ppt
                    } else {
                        previewMode = .web
                    }
                }
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

    private func triggerWebGeneration() {
        let latestPrompt = chatState.messages
            .last(where: { $0.role == .user })?.content ?? ""

        Task {
            await generationEngine.generate(
                description: latestPrompt,
                drawing: canvasState.drawing,
                previousHTML: generationEngine.generatedHTML
            )
            if !canvasState.isPreviewVisible {
                canvasState.togglePreview()
            }
        }
    }

    private func triggerPPTGeneration() {
        let latestPrompt = chatState.messages
            .last(where: { $0.role == .user })?.content ?? ""

        Task {
            await pptGenerator.generate(description: latestPrompt)
            if !canvasState.isPreviewVisible {
                canvasState.togglePreview()
            }
        }
    }

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
