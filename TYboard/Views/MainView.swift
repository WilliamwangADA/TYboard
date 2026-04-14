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
    @State private var taskStore = TaskProjectStore()
    @State private var previewMode: PreviewMode = .web
    @State private var showAssetLibrary = false
    @State private var showTemplatePicker = false
    @State private var showTaskSwitcher = false
    @State private var showNewTask = false
    @State private var isPreviewFullscreen = false

    // Drag handle for resizing
    @GestureState private var dragOffset: CGFloat = 0

    var body: some View {
        NavigationStack {
            GeometryReader { geometry in
                if isPreviewFullscreen {
                    // Fullscreen preview mode
                    fullscreenPreview(in: geometry)
                } else {
                    // Normal split layout
                    splitLayout(in: geometry)
                }
            }
            .ignoresSafeArea(.keyboard)
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    // Task switcher
                    Menu {
                        Button {
                            showNewTask = true
                        } label: {
                            Label("新建任务", systemImage: "plus")
                        }

                        Button {
                            showTaskSwitcher = true
                        } label: {
                            Label("所有任务", systemImage: "list.bullet")
                        }

                        Divider()

                        // Quick switch to recent tasks
                        ForEach(taskStore.activeProjects.prefix(5)) { project in
                            Button {
                                taskStore.switchTo(project)
                            } label: {
                                Label(project.name, systemImage: project.type.iconName)
                            }
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: taskStore.currentProject?.type.iconName ?? "square.on.square")
                            Text(taskStore.currentProject?.name ?? "TYboard")
                                .font(.headline)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                        }
                    }

                    // Canvas background picker
                    Menu {
                        ForEach(CanvasState.CanvasBackground.allCases, id: \.self) { bg in
                            Button {
                                canvasState.canvasBackground = bg
                            } label: {
                                Label(bg.rawValue, systemImage: bg.iconName)
                            }
                        }
                    } label: {
                        Image(systemName: canvasState.canvasBackground.iconName)
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
                    Button {
                        previewMode = .web
                        triggerWebGeneration()
                    } label: {
                        Label("生成Web", systemImage: "wand.and.stars")
                    }
                    .disabled(generationEngine.isGenerating)

                    Button {
                        previewMode = .ppt
                        triggerPPTGeneration()
                    } label: {
                        Label("生成PPT", systemImage: "rectangle.on.rectangle.angled")
                    }
                    .disabled(pptGenerator.isGenerating)

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
                    previewMode = template.category == .ppt ? .ppt : .web
                }
            }
            .sheet(isPresented: $showTaskSwitcher) {
                TaskSwitcherView(store: taskStore, isPresented: $showTaskSwitcher)
            }
            .sheet(isPresented: $showNewTask) {
                NewTaskSheet(isPresented: $showNewTask) { name, type in
                    _ = taskStore.createProject(name: name, type: type)
                }
            }
        }
    }

    // MARK: - Split Layout

    @ViewBuilder
    private func splitLayout(in geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Canvas area
            ZStack {
                InfiniteCanvasView(state: canvasState)

                VStack {
                    DrawingToolBar(
                        selectedTool: $canvasState.selectedTool,
                        selectedColor: $canvasState.selectedColor,
                        lineWidth: $canvasState.lineWidth
                    )
                    .padding(.top, 8)

                    Spacer()

                    ChatInputBar(state: chatState) {
                        chatState.attachCanvasSnapshot(canvasState.drawing)
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
            .frame(width: effectiveCanvasWidth(in: geometry))

            // Draggable divider
            if canvasState.isPreviewVisible {
                Rectangle()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(width: 8)
                    .gesture(
                        DragGesture()
                            .updating($dragOffset) { value, state, _ in
                                state = value.translation.width
                            }
                            .onEnded { value in
                                let delta = -value.translation.width / geometry.size.width
                                let newRatio = canvasState.previewWidthRatio + delta
                                canvasState.previewWidthRatio = min(max(newRatio, 0.15), 0.7)
                            }
                    )
                    .onTapGesture(count: 2) {
                        withAnimation { isPreviewFullscreen = true }
                    }

                // Preview area
                VStack(spacing: 0) {
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
                .frame(width: effectivePreviewWidth(in: geometry))
                .transition(.move(edge: .trailing))
            }
        }
    }

    // MARK: - Fullscreen Preview

    @ViewBuilder
    private func fullscreenPreview(in geometry: GeometryProxy) -> some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Button {
                    withAnimation { isPreviewFullscreen = false }
                } label: {
                    Label("返回画布", systemImage: "arrow.left")
                }

                Spacer()

                Picker("", selection: $previewMode) {
                    ForEach(PreviewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 200)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Full preview with chat input overlay
            ZStack(alignment: .bottom) {
                switch previewMode {
                case .web:
                    PreviewPanel(
                        canvasState: canvasState,
                        generationEngine: generationEngine
                    )
                case .ppt:
                    PPTPreviewPanel(generator: pptGenerator)
                }

                // Chat input for direct modifications
                ChatInputBar(state: chatState) {
                    chatState.attachCanvasSnapshot(canvasState.drawing)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
    }

    // MARK: - Width calculations with drag support

    private func effectiveCanvasWidth(in geometry: GeometryProxy) -> CGFloat {
        if canvasState.isPreviewVisible {
            let adjustedRatio = canvasState.previewWidthRatio + (-dragOffset / geometry.size.width)
            let clampedRatio = min(max(adjustedRatio, 0.15), 0.7)
            return geometry.size.width * (1 - clampedRatio) - 8 // 8 for divider
        }
        return geometry.size.width
    }

    private func effectivePreviewWidth(in geometry: GeometryProxy) -> CGFloat {
        let adjustedRatio = canvasState.previewWidthRatio + (-dragOffset / geometry.size.width)
        let clampedRatio = min(max(adjustedRatio, 0.15), 0.7)
        return geometry.size.width * clampedRatio
    }

    // MARK: - Actions

    private func triggerWebGeneration() {
        let latestPrompt = chatState.messages
            .last(where: { $0.role == .user })?.content ?? ""
        Task {
            await generationEngine.generate(
                description: latestPrompt,
                drawing: canvasState.drawing,
                previousHTML: generationEngine.generatedHTML
            )
            if !canvasState.isPreviewVisible { canvasState.togglePreview() }
        }
    }

    private func triggerPPTGeneration() {
        let latestPrompt = chatState.messages
            .last(where: { $0.role == .user })?.content ?? ""
        Task {
            await pptGenerator.generate(description: latestPrompt)
            if !canvasState.isPreviewVisible { canvasState.togglePreview() }
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
            if !canvasState.isPreviewVisible { canvasState.togglePreview() }
        }
    }
}
