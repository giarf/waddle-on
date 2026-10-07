import AppKit

/// Original Club Penguin sprite animation. All calls belong on the main thread.
final class PenguinView: NSView {
    private static let frames: [[NSImage]] = loadFrames()
    private var direction = 0
    private var walking = false
    private var animationTime: TimeInterval = 0
    private var lastTick: TimeInterval = 0
    private var timer: Timer?

    override var intrinsicContentSize: NSSize { NSSize(width: 100, height: 110) }
    override var isOpaque: Bool { false }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setAccessibilityElement(true)
        setAccessibilityRole(.image)
        setAccessibilityLabel("Waddle On penguin")
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    deinit { timer?.invalidate() }

    /// `delta` uses AppKit screen coordinates: +x right, +y up.
    /// A zero vector retains the last facing direction.
    func setWalking(_ walking: Bool, toward delta: CGVector) {
        if delta.dx.isFinite, delta.dy.isFinite, hypot(delta.dx, delta.dy) > 0.001 {
            // Atlas order: south, southwest, west, northwest, north, northeast, east, southeast.
            let angle = atan2(-delta.dx, -delta.dy)
            direction = (Int((angle / (.pi / 4)).rounded()) + 8) % 8
        }
        if self.walking != walking {
            self.walking = walking
            animationTime = 0
            lastTick = ProcessInfo.processInfo.systemUptime
        }
        needsDisplay = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        timer?.invalidate()
        timer = nil
        guard window != nil else { return }
        lastTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 24, repeats: true) { [weak self] _ in
            guard let self else { return }
            let now = ProcessInfo.processInfo.systemUptime
            self.animationTime += min(now - self.lastTick, 0.1)
            self.lastTick = now
            self.needsDisplay = true
        }
        timer.tolerance = 0.008
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard Self.frames.count == 8 else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let index = walking && !reduceMotion ? 1 + Int(animationTime * 24) % 8 : 0
        let image = Self.frames[direction][index]
        let scale = min(bounds.width / 127, bounds.height / 142)
        guard scale > 0 else { return }
        let size = NSSize(width: 127 * scale, height: 142 * scale)
        // Idle breathing is a tiny presentation transform of the authentic standing frame.
        let breath = !walking && !reduceMotion ? sin(animationTime * .pi) * 0.65 : 0
        let rect = NSRect(x: bounds.midX - size.width / 2,
                          y: bounds.midY - size.height / 2,
                          width: size.width, height: size.height + breath)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: nil)
    }

    private static func loadFrames() -> [[NSImage]] {
        // SwiftPM's generated accessor looks beside the executable or in the build
        // tree. App bundles must resolve their embedded resources independently.
        let resources: Bundle
        if let url = Bundle.main.url(forResource: "WaddleOn_WaddleOn", withExtension: "bundle"),
           let embedded = Bundle(url: url) {
            resources = embedded
        } else {
            resources = Bundle.module
        }
        guard let url = resources.url(forResource: "penguin-atlas", withExtension: "png",
                                          subdirectory: "Resources/Penguin"),
              let image = NSImage(contentsOf: url),
              let atlas = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              atlas.width == 1143, atlas.height == 1136 else {
            NSLog("Waddle On: missing or invalid Resources/Penguin/penguin-atlas.png")
            return []
        }
        var rows: [[NSImage]] = []
        for row in 0..<8 {
            var frames: [NSImage] = []
            for column in 0..<9 {
                guard let frame = atlas.cropping(to: CGRect(x: column * 127, y: row * 142,
                                                            width: 127, height: 142)) else { return [] }
                frames.append(NSImage(cgImage: frame, size: NSSize(width: 127, height: 142)))
            }
            rows.append(frames)
        }
        return rows
    }
}
