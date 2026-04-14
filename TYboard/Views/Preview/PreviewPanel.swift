import SwiftUI
import WebKit

struct PreviewPanel: View {
    @Bindable var canvasState: CanvasState
    @State private var previewContent: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // Preview header
            HStack {
                Image(systemName: "eye")
                Text("预览")
                    .font(.headline)
                Spacer()

                // Preview controls
                Button {
                    // TODO: Phase 3 - Refresh preview
                } label: {
                    Image(systemName: "arrow.clockwise")
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

            Divider()

            // Preview content
            if previewContent.isEmpty {
                emptyStateView
            } else {
                WebPreviewView(htmlContent: previewContent)
            }
        }
        .background(Color(.systemBackground))
    }

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
}

struct WebPreviewView: UIViewRepresentable {
    let htmlContent: String

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        webView.loadHTMLString(htmlContent, baseURL: nil)
    }
}
