import SwiftUI
import PencilKit

struct InfiniteCanvasView: UIViewRepresentable {
    @Bindable var state: CanvasState

    func makeUIView(context: Context) -> InfiniteCanvasUIView {
        let canvasView = InfiniteCanvasUIView(state: state)
        return canvasView
    }

    func updateUIView(_ uiView: InfiniteCanvasUIView, context: Context) {
        // State updates handled via observation in UIView
    }
}

final class InfiniteCanvasUIView: UIView {
    private let scrollView = UIScrollView()
    private let canvasView = PKCanvasView()
    private let state: CanvasState

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
        canvasView.drawingPolicy = .pencilOnly
        canvasView.backgroundColor = .clear
        canvasView.isOpaque = false
        canvasView.tool = PKInkingTool(.pen, color: .label, width: 3)
        canvasView.drawing = state.drawing
        canvasView.delegate = self

        // Use a container for the infinite canvas
        let containerView = UIView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.backgroundColor = UIColor.systemBackground

        // Add grid pattern
        let gridLayer = GridLayer()
        gridLayer.frame = CGRect(origin: .zero, size: state.canvasSize)
        containerView.layer.addSublayer(gridLayer)

        scrollView.addSubview(containerView)
        containerView.addSubview(canvasView)

        NSLayoutConstraint.activate([
            containerView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            containerView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor),
            containerView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            containerView.widthAnchor.constraint(equalToConstant: state.canvasSize.width),
            containerView.heightAnchor.constraint(equalToConstant: state.canvasSize.height),

            canvasView.topAnchor.constraint(equalTo: containerView.topAnchor),
            canvasView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor),
            canvasView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor),
            canvasView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor),
        ])
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
    private let gridColor = UIColor.separator.withAlphaComponent(0.3)

    override func draw(in ctx: CGContext) {
        ctx.setStrokeColor(gridColor.cgColor)
        ctx.setLineWidth(0.5)

        let width = bounds.width
        let height = bounds.height

        // Vertical lines
        var x: CGFloat = 0
        while x <= width {
            ctx.move(to: CGPoint(x: x, y: 0))
            ctx.addLine(to: CGPoint(x: x, y: height))
            x += gridSpacing
        }

        // Horizontal lines
        var y: CGFloat = 0
        while y <= height {
            ctx.move(to: CGPoint(x: 0, y: y))
            ctx.addLine(to: CGPoint(x: width, y: y))
            y += gridSpacing
        }

        ctx.strokePath()
    }

    override init() {
        super.init()
        setNeedsDisplay()
    }

    override init(layer: Any) {
        super.init(layer: layer)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
