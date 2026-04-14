import Foundation

/// Extracts code blocks from AI responses
enum CodeExtractor {
    struct ExtractedCode {
        let language: String
        let code: String
    }

    /// Extract all code blocks from markdown-formatted text
    static func extractCodeBlocks(from text: String) -> [ExtractedCode] {
        var results: [ExtractedCode] = []
        let pattern = "```(\\w*)\\n([\\s\\S]*?)```"

        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return results
        }

        let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))

        for match in matches {
            let languageRange = Range(match.range(at: 1), in: text)
            let codeRange = Range(match.range(at: 2), in: text)

            if let codeRange {
                let language = languageRange.map { String(text[$0]) } ?? ""
                let code = String(text[codeRange]).trimmingCharacters(in: .whitespacesAndNewlines)
                results.append(ExtractedCode(language: language, code: code))
            }
        }

        return results
    }

    /// Extract the first HTML code block, or treat full response as HTML if it starts with <!DOCTYPE or <html
    static func extractHTML(from text: String) -> String? {
        // Try code blocks first
        let blocks = extractCodeBlocks(from: text)
        if let htmlBlock = blocks.first(where: { $0.language.lowercased() == "html" }) {
            return htmlBlock.code
        }

        // Check if any block looks like HTML
        if let htmlLike = blocks.first(where: { $0.code.contains("<html") || $0.code.contains("<!DOCTYPE") }) {
            return htmlLike.code
        }

        // Check if the raw text itself is HTML
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("<!DOCTYPE") || trimmed.hasPrefix("<html") {
            return trimmed
        }

        return nil
    }

    /// Extract separate CSS and JS from response if provided separately
    static func extractComponents(from text: String) -> (html: String?, css: String?, js: String?) {
        let blocks = extractCodeBlocks(from: text)

        let html = blocks.first(where: { $0.language.lowercased() == "html" })?.code
        let css = blocks.first(where: { $0.language.lowercased() == "css" })?.code
        let js = blocks.first(where: { ["javascript", "js"].contains($0.language.lowercased()) })?.code

        return (html, css, js)
    }

    /// Combine separate HTML/CSS/JS into a single HTML file
    static func combineToHTML(html: String?, css: String?, js: String?) -> String? {
        guard let html else { return nil }

        var result = html

        // Inject CSS if provided separately and not already in HTML
        if let css, !html.contains("<style>") {
            let styleTag = "<style>\n\(css)\n</style>"
            if let headEnd = result.range(of: "</head>") {
                result.insert(contentsOf: "\n\(styleTag)\n", at: headEnd.lowerBound)
            }
        }

        // Inject JS if provided separately and not already in HTML
        if let js, !html.contains("<script>") {
            let scriptTag = "<script>\n\(js)\n</script>"
            if let bodyEnd = result.range(of: "</body>") {
                result.insert(contentsOf: "\n\(scriptTag)\n", at: bodyEnd.lowerBound)
            }
        }

        return result
    }
}
