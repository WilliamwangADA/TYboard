import Foundation

/// Generates PPT/Presentation from description using Claude API
@Observable
final class PPTGenerator {
    var currentPresentation: Presentation?
    var isGenerating = false

    /// Generate a presentation from description
    func generate(description: String, theme: PresentationTheme = .modern) async {
        await MainActor.run { isGenerating = true }
        defer { Task { @MainActor in isGenerating = false } }

        let systemPrompt = """
        你是一个专业的演示文稿设计师。根据用户的描述生成演示文稿结构。

        输出严格的JSON格式，不要输出其他内容：
        ```json
        {
            "title": "演示标题",
            "slides": [
                {
                    "title": "幻灯片标题",
                    "content": "内容（支持markdown格式，用\\n换行）",
                    "notes": "演讲者备注",
                    "layout": "title|title-content|two-column|image-left|image-right|image-full|blank",
                    "backgroundColor": "#hex颜色（可选）"
                }
            ]
        }
        ```

        ## 设计原则
        - 第一页为标题页（layout: "title"）
        - 每页内容精炼，不超过5个要点
        - 合理使用不同layout增加视觉变化
        - 内容结构清晰，逻辑连贯
        - 通常8-15页为宜
        """

        do {
            let response = try await ClaudeAPIService.shared.sendMessageSync(
                messages: [
                    ClaudeAPIService.Message(role: "user", content: [.text(description)])
                ],
                systemPrompt: systemPrompt
            )

            if let presentation = parsePresentation(from: response, theme: theme) {
                await MainActor.run {
                    currentPresentation = presentation
                }
            }
        } catch {
            // Error handled silently
        }
    }

    /// Parse JSON response into Presentation
    private func parsePresentation(from text: String, theme: PresentationTheme) -> Presentation? {
        // Extract JSON from code block or raw text
        let jsonString: String
        if let match = text.range(of: "```json\\n([\\s\\S]*?)```", options: .regularExpression) {
            let extracted = String(text[match])
            jsonString = extracted
                .replacingOccurrences(of: "```json\n", with: "")
                .replacingOccurrences(of: "```", with: "")
        } else if let start = text.firstIndex(of: "{"),
                  let end = text.lastIndex(of: "}") {
            jsonString = String(text[start...end])
        } else {
            return nil
        }

        guard let data = jsonString.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        let title = json["title"] as? String ?? "未命名演示"
        guard let slidesArray = json["slides"] as? [[String: Any]] else { return nil }

        let slides = slidesArray.map { slideJson -> SlideData in
            SlideData(
                title: slideJson["title"] as? String ?? "",
                content: slideJson["content"] as? String ?? "",
                notes: slideJson["notes"] as? String ?? "",
                layout: SlideData.SlideLayout(rawValue: slideJson["layout"] as? String ?? "title-content") ?? .titleContent,
                imageURL: slideJson["imageURL"] as? String,
                backgroundColor: slideJson["backgroundColor"] as? String
            )
        }

        return Presentation(title: title, theme: theme, slides: slides)
    }

    /// Render presentation as full HTML using reveal.js CDN
    func renderHTML() -> String? {
        guard let pres = currentPresentation else { return nil }

        let slidesHTML = pres.slides.map { slide in
            renderSlide(slide, theme: pres.theme)
        }.joined(separator: "\n")

        let themeCSS = themeStyles(pres.theme)

        return """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>\(pres.title)</title>
            <link rel="stylesheet" href="https://cdn.jsdelivr.net/npm/reveal.js@4.6.1/dist/reveal.css">
            <style>
                \(themeCSS)
                .reveal { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; }
                .reveal h1, .reveal h2, .reveal h3 { font-weight: 700; }
                .reveal ul { text-align: left; }
                .reveal .slide-content { padding: 20px; }
                .two-column { display: flex; gap: 40px; }
                .two-column > div { flex: 1; }
            </style>
        </head>
        <body>
            <div class="reveal">
                <div class="slides">
                    \(slidesHTML)
                </div>
            </div>
            <script src="https://cdn.jsdelivr.net/npm/reveal.js@4.6.1/dist/reveal.js"></script>
            <script>
                Reveal.initialize({
                    hash: true,
                    transition: 'slide',
                    controls: true,
                    progress: true,
                    center: true
                });
            </script>
        </body>
        </html>
        """
    }

    private func renderSlide(_ slide: SlideData, theme: PresentationTheme) -> String {
        let bgStyle = slide.backgroundColor.map { " data-background-color=\"\($0)\"" } ?? ""
        let contentHTML = markdownToHTML(slide.content)

        switch slide.layout {
        case .titleSlide:
            return """
            <section\(bgStyle)>
                <h1>\(slide.title)</h1>
                <p>\(contentHTML)</p>
            </section>
            """
        case .titleContent:
            return """
            <section\(bgStyle)>
                <h2>\(slide.title)</h2>
                <div class="slide-content">\(contentHTML)</div>
            </section>
            """
        case .twoColumn:
            let parts = slide.content.components(separatedBy: "|||")
            let left = parts.first.map { markdownToHTML($0) } ?? ""
            let right = parts.count > 1 ? markdownToHTML(parts[1]) : ""
            return """
            <section\(bgStyle)>
                <h2>\(slide.title)</h2>
                <div class="two-column">
                    <div>\(left)</div>
                    <div>\(right)</div>
                </div>
            </section>
            """
        case .imageLeft:
            return """
            <section\(bgStyle)>
                <h2>\(slide.title)</h2>
                <div class="two-column">
                    <div><img src="\(slide.imageURL ?? "")" style="max-width:100%"></div>
                    <div>\(contentHTML)</div>
                </div>
            </section>
            """
        case .imageRight:
            return """
            <section\(bgStyle)>
                <h2>\(slide.title)</h2>
                <div class="two-column">
                    <div>\(contentHTML)</div>
                    <div><img src="\(slide.imageURL ?? "")" style="max-width:100%"></div>
                </div>
            </section>
            """
        case .imageFull:
            return """
            <section data-background-image="\(slide.imageURL ?? "")"\(bgStyle)>
                <h2>\(slide.title)</h2>
                <p>\(contentHTML)</p>
            </section>
            """
        case .blank:
            return """
            <section\(bgStyle)>
                \(contentHTML)
            </section>
            """
        }
    }

    private func markdownToHTML(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\n- ", with: "\n<li>")
            .replacingOccurrences(of: "\\n", with: "<br>")
            .replacingOccurrences(of: "**", with: "<strong>", options: [], range: nil)
            .replacingOccurrences(of: "\n- ", with: "\n<li>")
            .replacingOccurrences(of: "\n", with: "<br>")
    }

    private func themeStyles(_ theme: PresentationTheme) -> String {
        switch theme {
        case .modern:
            return """
            .reveal { background: #ffffff; color: #333; }
            .reveal h1, .reveal h2 { color: #2563eb; }
            """
        case .minimal:
            return """
            .reveal { background: #fafafa; color: #222; }
            .reveal h1, .reveal h2 { color: #111; font-weight: 300; }
            """
        case .dark:
            return """
            .reveal { background: #1a1a2e; color: #eee; }
            .reveal h1, .reveal h2 { color: #e94560; }
            """
        case .colorful:
            return """
            .reveal { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: #fff; }
            .reveal h1, .reveal h2 { color: #fff; text-shadow: 2px 2px 4px rgba(0,0,0,0.3); }
            """
        }
    }

    /// Export as HTML file
    func exportHTML() -> URL? {
        guard let html = renderHTML() else { return nil }
        let tempDir = FileManager.default.temporaryDirectory
        let fileName = currentPresentation?.title ?? "presentation"
        let fileURL = tempDir.appendingPathComponent("\(fileName).html")

        do {
            try html.write(to: fileURL, atomically: true, encoding: .utf8)
            return fileURL
        } catch {
            return nil
        }
    }
}
