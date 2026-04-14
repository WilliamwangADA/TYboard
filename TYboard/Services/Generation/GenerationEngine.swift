import Foundation
import PencilKit

/// Manages the generation pipeline: sketch + text → code → preview
@Observable
final class GenerationEngine {
    var generatedHTML: String?
    var generationHistory: [GenerationSnapshot] = []
    var isGenerating: Bool = false
    var currentVersion: Int = 0

    struct GenerationSnapshot: Identifiable {
        let id = UUID()
        let version: Int
        let html: String
        let prompt: String
        let timestamp: Date
    }

    /// Generate web content from sketch + description
    func generate(
        description: String,
        drawing: PKDrawing? = nil,
        previousHTML: String? = nil
    ) async {
        await MainActor.run { isGenerating = true }

        defer {
            Task { @MainActor in isGenerating = false }
        }

        let systemPrompt = buildSystemPrompt(hasSketch: drawing != nil, hasPrevious: previousHTML != nil)
        var userContent = description

        if let previousHTML {
            userContent += "\n\n--- 当前版本代码 ---\n```html\n\(previousHTML)\n```\n\n请基于以上代码进行修改。"
        }

        do {
            var messages: [ClaudeAPIService.Message] = []

            // Add conversation context from history
            for snapshot in generationHistory.suffix(3) {
                messages.append(ClaudeAPIService.Message(
                    role: "user",
                    content: [.text(snapshot.prompt)]
                ))
                messages.append(ClaudeAPIService.Message(
                    role: "assistant",
                    content: [.text("```html\n\(snapshot.html)\n```")]
                ))
            }

            // Build current message
            var contentBlocks: [ClaudeAPIService.ContentBlock] = []

            if let drawing, let imageData = CanvasCapture.captureDrawing(drawing) {
                contentBlocks.append(.image(mediaType: "image/png", data: imageData.base64EncodedString()))
            }
            contentBlocks.append(.text(userContent))

            messages.append(ClaudeAPIService.Message(role: "user", content: contentBlocks))

            // Call Claude API
            var fullResponse = ""
            let stream = await ClaudeAPIService.shared.sendMessage(
                messages: messages,
                systemPrompt: systemPrompt,
                model: "claude-sonnet-4-20250514"
            )

            for try await chunk in stream {
                fullResponse += chunk
            }

            // Extract HTML from response
            let components = CodeExtractor.extractComponents(from: fullResponse)
            let html = CodeExtractor.combineToHTML(
                html: components.html,
                css: components.css,
                js: components.js
            ) ?? CodeExtractor.extractHTML(from: fullResponse)

            if let html {
                await MainActor.run {
                    currentVersion += 1
                    generatedHTML = html
                    generationHistory.append(GenerationSnapshot(
                        version: currentVersion,
                        html: html,
                        prompt: description,
                        timestamp: Date()
                    ))
                }
            }
        } catch {
            // Error handled silently, isGenerating reset in defer
        }
    }

    /// Iterate on current design with annotation feedback
    func iterateWithAnnotation(
        annotationImage: Data,
        feedback: String
    ) async {
        guard let currentHTML = generatedHTML else { return }

        await MainActor.run { isGenerating = true }
        defer { Task { @MainActor in isGenerating = false } }

        let prompt = """
        用户在预览效果上做了标注（见附图），并提供了修改意见：
        \(feedback)

        请根据标注和意见修改代码。
        """

        do {
            var messages: [ClaudeAPIService.Message] = []

            // Current code context
            messages.append(ClaudeAPIService.Message(
                role: "user",
                content: [.text("这是当前的代码：\n```html\n\(currentHTML)\n```")]
            ))
            messages.append(ClaudeAPIService.Message(
                role: "assistant",
                content: [.text("好的，我已了解当前代码。请告诉我需要修改什么。")]
            ))

            // Annotation + feedback
            messages.append(ClaudeAPIService.Message(
                role: "user",
                content: [
                    .image(mediaType: "image/png", data: annotationImage.base64EncodedString()),
                    .text(prompt),
                ]
            ))

            var fullResponse = ""
            let stream = await ClaudeAPIService.shared.sendMessage(
                messages: messages,
                systemPrompt: SystemPrompts.canvas
            )

            for try await chunk in stream {
                fullResponse += chunk
            }

            if let html = CodeExtractor.extractHTML(from: fullResponse) {
                await MainActor.run {
                    currentVersion += 1
                    generatedHTML = html
                    generationHistory.append(GenerationSnapshot(
                        version: currentVersion,
                        html: html,
                        prompt: feedback,
                        timestamp: Date()
                    ))
                }
            }
        } catch {
            // Error handled silently
        }
    }

    /// Revert to a previous version
    func revertTo(snapshot: GenerationSnapshot) {
        generatedHTML = snapshot.html
    }

    /// Export current HTML to file
    func exportHTML() -> URL? {
        guard let html = generatedHTML else { return nil }

        let tempDir = FileManager.default.temporaryDirectory
        let fileURL = tempDir.appendingPathComponent("TYboard_export_v\(currentVersion).html")

        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }

    private func buildSystemPrompt(hasSketch: Bool, hasPrevious: Bool) -> String {
        var prompt = """
        你是TYboard的代码生成引擎。你的任务是根据用户的描述\(hasSketch ? "和涂鸦草图" : "")生成完整的、可直接运行的HTML文件。

        ## 输出要求
        - 输出一个完整的HTML文件，包含内联的CSS和JavaScript
        - 代码用```html```代码块包裹
        - 确保代码可以直接在浏览器中运行，不依赖外部文件
        - 使用现代CSS（flexbox/grid）和原生JavaScript
        - 设计要美观、现代、响应式
        - 默认使用中文界面
        """

        if hasSketch {
            prompt += """

            ## 草图理解
            - 方框/矩形 → 容器、卡片、按钮、输入框
            - 圆形 → 按钮、图标、头像
            - 箭头 → 导航方向、数据流向、页面跳转
            - 线条 → 分割线、连接关系
            - 手写文字 → 标签、标题、内容提示
            - 整体布局参考草图的空间分布
            """
        }

        if hasPrevious {
            prompt += """

            ## 迭代修改
            - 基于已有代码修改，保持整体结构和风格
            - 只修改用户要求的部分，不要重写整个文件
            - 保留已有的功能和样式
            """
        }

        return prompt
    }
}
