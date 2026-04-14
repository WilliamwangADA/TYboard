import SwiftUI
import PencilKit

struct InfiniteCanvasView: UIViewRepresentable {
    @Bindable var state: CanvasState

    func makeUIView(context: Context) -> InfiniteCanvasUIView {
        let canvasView = InfiniteCanvasUIView(state: state)
        return canvasView
    }

    func updateUIView(_ uiView: InfiniteCanvasUIView, context: Context) {
        uiView.updateTool(state.currentPKTool)
        uiView.updateBackground(state.canvasBackground)
    }
}

final class InfiniteCanvasUIView: UIView {
    private let scrollView = UIScrollView()
    private let canvasView = PKCanvasView()
    private let state: CanvasState
    private var gridLayer: GridLayer?
    private var containerView: UIView?

    init(state: CanvasState) {
        self.state = state
        super.init(frame: .zero)
        setupScrollView()
        setupCanvasView()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func setupScrollView() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.minimumZoomScale = state.minScale
        scrollView.maximumZoomScale = state.maxScale
        scrollView.bouncesZoom = true
        scrollView.bounces = true
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.delegate = self
        scrollView.panGestureRecognizer.minimumNumberOfTouches = 2
        addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: bottomAnchor),
        ])
    }

    private func setupCanvasView() {
        canvasView.translatesAutoresizingMaskIntoConstraints = false
        canvasView.drawingPolicy = .anyInput
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 3)
        canvasView.drawing = state.drawing
        canvasView.delegate = self

        // Use a container for the infinite canvas
        let container = UIView()
        container.translatesAutoresizingMaskIntoConstraints = false
        container.backgroundColor = state.canvasBackground.bgColor
        self.containerView = container

        // Add grid pattern
        let grid = GridLayer(background: state.canvasBackground)
        grid.frame = CGRect(origin: .zero, size: state.canvasSize)
        container.layer.addSublayer(grid)
        self.gridLayer = grid

        scrollView.addSubview(container)
        container.addSubview(canvasView)

        NSLayoutConstraint.activate([
            container.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            container.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            container.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            container.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            container.widthAnchor.constraint(equalToConstant: state.canvasSize.width),
            container.heightAnchor.constraint(equalToConstant: state.canvasSize.height),

            canvasView.topAnchor.constraint(equalTo: container.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
    }

    func updateTool(_ tool: PKTool) {
        canvasView.tool = tool
    }

    func updateBackground(_ background: CanvasState.CanvasBackground) {
        containerView?.backgroundColor = background.bgColor
        gridLayer?.updateBackground(background)
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // Center the canvas on first layout
        if scrollView.contentOffset == .zero {
            let offsetX = (state.canvasSize.width - scrollView.bounds.width) / 2
            let offsetY = (state.canvasSize.height - scrollView.bounds.height) / 2
            scrollView.contentOffset = CGPoint(x: offsetX, y: offsetY)
        }
    }
}

// MARK: - UIScrollViewDelegate
extension InfiniteCanvasUIView: UIScrollViewDelegate {
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        scrollView.subviews.first
    }

    func scrollViewDidZoom(_ scrollView: UIScrollView) {
        state.scale = scrollView.zoomScale
    }

    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        state.offset = scrollView.contentOffset
    }
}

// MARK: - PKCanvasViewDelegate
extension InfiniteCanvasUIView: PKCanvasViewDelegate {
    func canvasViewDrawingDidChange(_ canvasView: PKCanvasView) {
        state.drawing = canvasView.drawing
    }
}

// MARK: - Grid Pattern Layer
final class GridLayer: CALayer {
    private let gridSpacing: CGFloat = 40
    private var background: CanvasState.CanvasBackground

    init(background: CanvasState.CanvasBackground = .grid) {
        self.background = background
        super.init()
        setNeedsDisplay()
    }

    override init(layer: Any) {
        self.background = .grid
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func updateBackground(_ bg: CanvasState.CanvasBackground) {
        self.background = bg
        setNeedsDisplay()
    }

    override func draw(in ctx: CGContext) {
        let color = background.lineColor
        let width = bounds.width
        let height = bounds.height

        switch background {
        case .white:
            break // No pattern

        case .grid:
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(0.5)
            var x: CGFloat = 0
            while x <= width {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: height))
                x += gridSpacing
            }
            var y: CGFloat = 0
            while y <= height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: width, y: y))
                y += gridSpacing
            }
            ctx.strokePath()

        case .dots:
            ctx.setFillColor(color.cgColor)
            let dotRadius: CGFloat = 1.5
            var x: CGFloat = 0
            while x <= width {
                var y: CGFloat = 0
                while y <= height {
                    ctx.fillEllipse(in: CGRect(x: x - dotRadius, y: y - dotRadius, width: dotRadius * 2, height: dotRadius * 2))
                    y += gridSpacing
                }
                x += gridSpacing
            }

        case .blackboard:
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(0.5)
            var x: CGFloat = 0
            while x <= width {
                ctx.move(to: CGPoint(x: x, y: 0))
                ctx.addLine(to: CGPoint(x: x, y: height))
                x += gridSpacing
            }
            var y: CGFloat = 0
            while y <= height {
                ctx.move(to: CGPoint(x: 0, y: y))
                ctx.addLine(to: CGPoint(x: width, y: y))
                y += gridSpacing
            }
            ctx.strokePath()
        }
    }
}
