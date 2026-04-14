import SwiftUI
import PencilKit

struct DrawingToolBar: View {
    @Binding var selectedTool: DrawingTool
    @Binding var selectedColor: Color
    @Binding var lineWidth: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            // Tool buttons
            ForEach(DrawingTool.allCases) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    Image(systemName: tool.iconName)
                        .font(.title3)
                        .foregroundStyle(selectedTool == tool ? Color.accentColor : .secondary)
                        .frame(width: 40, height: 40)
                        .background(
                            selectedTool == tool
                            ? Color.accentColor.opacity(0.15)
                            : Color.clear,
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                }
            }

            Divider()
                .frame(height: 30)

            // Color picker
            ColorPicker("", selection: $selectedColor)
                .labelsHidden()
                .frame(width: 30, height: 30)

            // Quick colors
            ForEach(quickColors, id: \.self) { color in
                Circle()
                    .fill(color)
                    .frame(width: 24, height: 24)
                    .overlay(
                        Circle()
                            .strokeBorder(Color.primary, lineWidth: selectedColor == color ? 2 : 0)
                    )
                    .onTapGesture {
                        selectedColor = color
                    }
            }

            Divider()
                .frame(height: 30)

            // Line width slider
            Image(systemName: "line.diagonal")
                .font(.caption)
            Slider(value: $lineWidth, in: 1...20, step: 1)
                .frame(width: 100)
            Text("\(Int(lineWidth))")
                .font(.caption)
                .monospacedDigit()
                .frame(width: 24)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(.regularMaterial, in: Capsule())
    }

    private var quickColors: [Color] {
        [.black, .red, .blue, .green, .orange]
    }
}

enum DrawingTool: String, CaseIterable, Identifiable {
    case pen
    case marker
    case pencil
    case eraser

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .pen: "pencil.tip"
        case .marker: "highlighter"
        case .pencil: "pencil"
        case .eraser: "eraser"
        }
    }

    func pkTool(color: UIColor, width: CGFloat) -> PKTool {
        switch self {
        case .pen: PKInkingTool(.pen, color: color, width: width)
        case .marker: PKInkingTool(.marker, color: color, width: width)
        case .pencil: PKInkingTool(.pencil, color: color, width: width)
        case .eraser: PKEraserTool(.bitmap)
        }
    }
}
