import AppKit

/// Screen-space trajectory for the native AppKit snowball effect (not a game sprite).
struct SnowballTrajectory {
    let start: NSPoint
    let target: NSPoint

    var duration: TimeInterval { min(1.2, max(0.35, hypot(target.x - start.x, target.y - start.y) / 900)) }

    func position(progress: Double) -> NSPoint {
        let t = CGFloat(min(1, max(0, progress)))
        let arc = min(180, max(45, hypot(target.x - start.x, target.y - start.y) * 0.2))
        return NSPoint(x: start.x + (target.x - start.x) * t,
                       y: start.y + (target.y - start.y) * t + 4 * arc * t * (1 - t))
    }

    static func clampedInterval(_ interval: Double) -> Double {
        interval.isFinite ? min(300, max(5, interval)) : 20
    }

    static func randomDelay(interval: Double) -> TimeInterval {
        clampedInterval(interval) * Double.random(in: 0.75...1.25)
    }
}

/// A small click-through window follows the arc across global screen coordinates.
final class SnowballProjectile {
    let panel: NSPanel
    private let view: NativeSnowballView
    private let trajectory: SnowballTrajectory
    private let launchedAt: TimeInterval
    private let impactDuration: TimeInterval = 0.22

    init(start: NSPoint, target: NSPoint, launchedAt: TimeInterval) {
        trajectory = SnowballTrajectory(start: start, target: target)
        self.launchedAt = launchedAt
        panel = SnowballPanel(contentRect: NSRect(x: start.x - 24, y: start.y - 24, width: 48, height: 48),
                              styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        view = NativeSnowballView(frame: NSRect(x: 0, y: 0, width: 48, height: 48))
        panel.contentView = view
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.ignoresMouseEvents = true
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.orderFrontRegardless()
    }

    @discardableResult func advance(now: TimeInterval) -> Bool {
        let elapsed = max(0, now - launchedAt)
        guard elapsed < trajectory.duration + impactDuration else { stop(); return false }
        let position = trajectory.position(progress: elapsed / trajectory.duration)
        panel.setFrameOrigin(NSPoint(x: position.x - 24, y: position.y - 24))
        view.impact = elapsed >= trajectory.duration ? (elapsed - trajectory.duration) / impactDuration : nil
        view.needsDisplay = true
        return true
    }

    func stop() { panel.orderOut(nil) }
}

private final class SnowballPanel: NSPanel {
    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}

private final class NativeSnowballView: NSView {
    var impact: Double?
    override var isOpaque: Bool { false }

    override func draw(_ dirtyRect: NSRect) {
        if let impact {
            for index in 0..<8 {
                let angle = Double(index) * .pi / 4
                let radius = 4 + impact * 16
                let size = 4 * (1 - impact) + 1
                let rect = NSRect(x: 24 + cos(angle) * radius - size / 2,
                                  y: 24 + sin(angle) * radius - size / 2, width: size, height: size)
                NSColor.white.withAlphaComponent(1 - impact).setFill()
                NSBezierPath(ovalIn: rect).fill()
            }
        } else {
            let ball = NSBezierPath(ovalIn: NSRect(x: 17, y: 17, width: 14, height: 14))
            NSColor.white.setFill()
            ball.fill()
            NSColor(calibratedRed: 0.58, green: 0.76, blue: 0.88, alpha: 1).setStroke()
            ball.lineWidth = 1.5
            ball.stroke()
        }
    }
}
