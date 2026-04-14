import SwiftUI
import WebKit

struct PPTPreviewPanel: View {
    @Bindable var generator: PPTGenerator
    @State private var selectedTheme: PresentationTheme = .modern
    @State private var showExport = false
    @State private var exportURL: URL?

    var body: some View {
        VStack(spacing: 0) {
            // Theme selector
            HStack {
                Text("主题")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("", selection: $selectedTheme) {
                    ForEach(PresentationTheme.allCases, id: \.self) { theme in
                        Text(theme.displayName).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 300)

                Spacer()

                if generator.currentPresentation != nil {
                    Button {
                        exportURL = generator.exportHTML()
                        if exportURL != nil { showExport = true }
                    } label: {
                        Label("导出", systemImage: "square.and.arrow.up")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // PPT preview
            if let html = generator.renderHTML() {
                WebPreviewView(htmlContent: html)
            } else if generator.isGenerating {
                VStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Text("正在生成演示文稿...")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.top, 12)
                    Spacer()
                }
            } else {
                VStack {
                    Spacer()
                    Image(systemName: "rectangle.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(.tertiary)
                    Text("描述你的PPT主题，AI将为你生成")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }

            // Slide thumbnails bar
            if let pres = generator.currentPresentation, !pres.slides.isEmpty {
                Divider()
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(pres.slides.enumerated()), id: \.element.id) { index, slide in
                            VStack(spacing: 4) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.secondary.opacity(0.1))
                                    .frame(width: 80, height: 50)
                                    .overlay(
                                        Text(slide.title)
                                            .font(.system(size: 7))
                                            .lineLimit(2)
                                            .padding(4)
                                    )
                                Text("\(index + 1)")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                }
                .frame(height: 80)
                .background(.bar)
            }
        }
        .sheet(isPresented: $showExport) {
            if let url = exportURL {
                ShareSheet(url: url)
            }
        }
        .onChange(of: selectedTheme) {
            generator.currentPresentation?.theme = selectedTheme
        }
    }
}
