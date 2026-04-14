import SwiftUI
import WebKit
import PencilKit

struct PreviewPanel: View {
    @Bindable var canvasState: CanvasState
    @Bindable var generationEngine: GenerationEngine
    @State private var isAnnotating = false
    @State private var annotationDrawing = PKDrawing()
    @State private var feedbackText = ""
    @State private var showVersionHistory = false
    @State private var showExportSheet = false
    @State private var exportURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            previewHeader
            Divider()

            if let html = generationEngine.generatedHTML {
                ZStack {
                    WebPreviewView(htmlContent: html)

                    if isAnnotating {
                        annotationOverlay
                    }
                }

                if isAnnotating {
                    annotationToolbar
                }
            } else if generationEngine.isGenerating {
                generatingView
            } else {
                emptyStateView
            }
        }
        .background(Color(.systemBackground))
        .sheet(isPresented: $showVersionHistory) {
            VersionHistorySheet(
                engine: generationEngine,
                isPresented: $showVersionHistory
            )
        }
        .sheet(isPresented: $showExportSheet) {
            if let url = exportURL {
                ShareSheet(url: url)
            }
        }
    }

    // MARK: - Header

    private var previewHeader: some View {
        HStack {
            Image(systemName: "eye")
            Text("预览")
                .font(.headline)

            if generationEngine.currentVersion > 0 {
                Text("v\(generationEngine.currentVersion)")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.blue.opacity(0.15), in: Capsule())
            }

            Spacer()

            // Annotate toggle
            if generationEngine.generatedHTML != nil {
                Button {
                    isAnnotating.toggle()
                    if !isAnnotating {
                        annotationDrawing = PKDrawing()
                    }
                } label: {
                    Image(systemName: isAnnotating ? "pencil.tip.crop.circle.fill" : "pencil.tip.crop.circle")
                        .foregroundStyle(isAnnotating ? .blue : .secondary)
                }

                // Version history
                Button {
                    showVersionHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }

                // Export
                Button {
                    exportURL = generationEngine.exportHTML()
                    if exportURL != nil {
                        showExportSheet = true
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
            }

            Button {
                canvasState.togglePreview()
            } label: {
                Image(systemName: "xmark")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.bar)
    }

    // MARK: - Annotation overlay

    private var annotationOverlay: some View {
        AnnotationCanvasView(drawing: $annotationDrawing)
            .background(Color.white.opacity(0.01)) // Capture touches
    }

    private var annotationToolbar: some View {
        HStack(spacing: 12) {
            TextField("描述需要的修改...", text: $feedbackText)
                .textFieldStyle(.roundedBorder)

            Button("发送修改") {
                submitAnnotation()
            }
            .buttonStyle(.borderedProminent)
            .disabled(feedbackText.isEmpty)

            Button {
                annotationDrawing = PKDrawing()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
        }
        .padding(10)
        .background(.bar)
    }

    // MARK: - States

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("在画布上涂鸦并描述你的想法")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("预览将在这里显示")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private var generatingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text("正在生成...")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private func submitAnnotation() {
        guard !feedbackText.isEmpty else { return }

        // Capture annotation as image
        let annotationImage = CanvasCapture.captureDrawing(annotationDrawing)

        let feedback = feedbackText
        feedbackText = ""
        annotationDrawing = PKDrawing()
        isAnnotating = false

        Task {
            if let imageData = annotationImage {
                await generationEngine.iterateWithAnnotation(
                    annotationImage: imageData,
                    feedback: feedback
                )
            }
        }
    }
}

// MARK: - Annotation Canvas (PencilKit overlay)

struct AnnotationCanvasView: UIViewRepresentable {
    @Binding var drawing: PKDrawing

    func makeUIView(context: Context) -> PKCanvasView {
        let canvas = PKCanvasView()
        canvas.drawingPolicy = .anyInput
        canvas.backgroundColor = .clear
        canvas.isOpaque = false
        canvas.tool = PKInkingTool(.pen, color: .systemRed, width: 3)
        canvas.delegate = context.coordinator
        return canvas
    }

    func updateUIView(_ uiView: PKCanvasView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(drawing: $drawing)
    }

    class Coordinator: NSObject, PKCanvasViewDelegate {
        @Binding var drawing: PKDrawing

        init(drawing: Binding<PKDrawing>) {
            _drawing = drawing
        }

        func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
            drawing = canvasView.drawing
        }
    }
}

// MARK: - Web Preview

struct WebPreviewView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        webView.scrollView.bounces = false
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
}

// MARK: - Version History Sheet

struct VersionHistorySheet: View {
    @Bindable var engine: GenerationEngine
    @Binding var isPresented: Bool

    var body: some View {
        NavigationStack {
            List(engine.generationHistory.reversed()) { snapshot in
                Button {
                    engine.revertTo(snapshot: snapshot)
                    isPresented = false
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text("v\(snapshot.version)")
                                .font(.headline)
                            Spacer()
                            Text(snapshot.timestamp, style: .time)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(snapshot.prompt)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }
            }
            .navigationTitle("版本历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { isPresented = false }
                }
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: [url], applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
