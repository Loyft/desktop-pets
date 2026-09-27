import AppKit

struct ScreenEdgeGeometry {
    /// Usable desktop area (excludes menu bar / Dock).
    let visibleFrame: CGRect
    let petSize: CGSize

    init(screen: NSScreen = NSScreen.main ?? NSScreen.screens[0], petSize: CGSize) {
        self.visibleFrame = screen.visibleFrame
        self.petSize = petSize
    }

    var minX: CGFloat { visibleFrame.minX }
    var maxX: CGFloat { visibleFrame.maxX - petSize.width }
    var minY: CGFloat { visibleFrame.minY }
    var maxY: CGFloat { visibleFrame.maxY - petSize.height }

    func clamp(_ origin: CGPoint, to side: EdgeSide) -> CGPoint {
        switch side {
        case .bottom:
            return CGPoint(x: min(max(origin.x, minX), maxX), y: minY)
        case .top:
            return CGPoint(x: min(max(origin.x, minX), maxX), y: maxY)
        case .left:
            return CGPoint(x: minX, y: min(max(origin.y, minY), maxY))
        case .right:
            return CGPoint(x: maxX, y: min(max(origin.y, minY), maxY))
        }
    }

    func startingOrigin(for side: EdgeSide) -> CGPoint {
        switch side {
        case .bottom:
            return CGPoint(x: visibleFrame.midX - petSize.width / 2, y: minY)
        case .top:
            return CGPoint(x: visibleFrame.midX - petSize.width / 2, y: maxY)
        case .left:
            return CGPoint(x: minX, y: visibleFrame.midY - petSize.height / 2)
        case .right:
            return CGPoint(x: maxX, y: visibleFrame.midY - petSize.height / 2)
        }
    }
}
