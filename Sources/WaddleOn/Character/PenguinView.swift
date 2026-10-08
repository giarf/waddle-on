import AppKit

/// Original Club Penguin sprite animation. All calls belong on the main thread.
final class PenguinView: NSView {
    private static let frames: [[NSImage]] = loadFrames()
    private static let danceFrames = loadActionFrames("dance", columns: 16, rows: 13, count: 193)
    private static let throwFrames = loadActionFrames("throw", columns: 28, rows: 4, count: 112)
    private static let preparedFrames: Void = {
        // Creating NSImage/CGImage crops alone can leave PNG pixels lazily
        // decoded. Draw every pose before any desktop movement is visible.
        guard let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 226,
            pixelsHigh: 213, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
              let context = NSGraphicsContext(bitmapImageRep: bitmap) else { return }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        for image in frames.flatMap({ $0 }) + danceFrames + throwFrames {
            context.cgContext.clear(CGRect(x: 0, y: 0, width: 226, height: 213))
            image.draw(in: NSRect(origin: .zero, size: image.size), from: .zero,
                       operation: .copy, fraction: 1)
        }
    }()
    static let snowballReleaseDelay: TimeInterval = 0.833
    static let throwDuration: TimeInterval = 28.0 / 24
    private enum Action { case dance, snowball }
    private var action: Action?
    private var actionStarted: TimeInterval = 0
    var isPerformingAction: Bool {
        action == .dance || (action == .snowball && actionElapsed < Self.throwDuration)
    }
    private var actionElapsed: TimeInterval {
        max(0, ProcessInfo.processInfo.systemUptime - actionStarted)
    }
    private(set) var direction = 0
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

    /// Load sprite sheets before the desktop starts moving the window.
    func prepareAnimations() {
        _ = Self.preparedFrames
        lastTick = ProcessInfo.processInfo.systemUptime
    }

    /// Also driven by the movement loop so translation cannot outrun animation
    /// when AppKit delays the independent redraw timer during startup.
    func advanceAnimation(at now: TimeInterval) {
        if lastTick > 0 { animationTime += max(0, now - lastTick) }
        lastTick = now
        if action == .snowball && actionElapsed >= Self.throwDuration { stopAction() }
        needsDisplay = true
    }

    var walkingFrameIndex: Int { 1 + Int(animationTime * 24) % 8 }

    /// `delta` uses AppKit screen coordinates: +x right, +y up.
    /// A zero vector retains the last facing direction.
    func setWalking(_ walking: Bool, toward delta: CGVector) {
        if walking || !isPerformingAction { stopAction() }
        guard action == nil else { return }
        face(toward: delta, stabilize: self.walking && walking)
        if self.walking != walking {
            self.walking = walking
            animationTime = 0
            lastTick = ProcessInfo.processInfo.systemUptime
        }
        needsDisplay = true
    }

    private func face(toward delta: CGVector, stabilize: Bool = false) {
        if delta.dx.isFinite, delta.dy.isFinite, hypot(delta.dx, delta.dy) > 0.001 {
            // Atlas order: south, southwest, west, northwest, north, northeast, east, southeast.
            let angle = atan2(-delta.dx, -delta.dy)
            // Keep the current pose near sector boundaries. Otherwise tiny
            // cursor/clamping changes alternate two sprite rows every tick.
            let center = Double(direction) * .pi / 4
            let difference = atan2(sin(angle - center), cos(angle - center))
            let margin = 8.0 * Double.pi / 180
            if stabilize && abs(difference) <= .pi / 8 + margin { return }
            direction = (Int((angle / (.pi / 4)).rounded()) + 8) % 8
        }
    }

    func toggleDance() {
        if action == .dance { stopAction(); return }
        guard Self.danceFrames.count == 193 else { return }
        direction = 0
        beginAction(.dance)
    }

    func throwSnowball(toward delta: CGVector) {
        guard Self.throwFrames.count == 112 else { return }
        face(toward: delta)
        beginAction(.snowball)
    }

    func stopAction() {
        guard action != nil else { return }
        action = nil
        animationTime = 0
        needsDisplay = true
    }

    private func beginAction(_ action: Action) {
        walking = false
        self.action = action
        actionStarted = ProcessInfo.processInfo.systemUptime
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
            self.advanceAnimation(at: ProcessInfo.processInfo.systemUptime)
        }
        timer.tolerance = 0.008
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Each frame has a different silhouette. Clear the previous pixels
        // instead of compositing transparent areas over the preceding pose.
        NSGraphicsContext.current?.cgContext.clear(bounds)
        guard Self.frames.count == 8 else { return }
        let reduceMotion = NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        let index = walking && !reduceMotion ? walkingFrameIndex : 0
        var image = Self.frames[direction][index]
        var isActionFrame = false
        if isPerformingAction && !reduceMotion {
            let frame = Int(actionElapsed * 24)
            if action == .dance {
                image = Self.danceFrames[frame % 193]
            } else {
                // Yukon: max(round((eight-way direction + 1) / 2), 1) + 26.
                image = Self.throwFrames[(direction / 2) * 28 + min(frame, 27)]
            }
            isActionFrame = true
        }
        // Fit one shared action canvas in every state: walking, standing and
        // actions retain exactly the same pixel scale and SWF registration point.
        let scale = min(bounds.width / 226, bounds.height / 213)
        guard scale > 0 else { return }
        let size = NSSize(width: 127 * scale, height: 142 * scale)
        // Idle breathing is a tiny presentation transform of the authentic standing frame.
        let breath = !walking && !isPerformingAction && !reduceMotion ? sin(animationTime * .pi) * 0.65 : 0
        let canvas = NSRect(x: bounds.midX - 113 * scale, y: bounds.midY - 106.5 * scale,
                            width: 226 * scale, height: 213 * scale)
        let rect = isActionFrame ? canvas : NSRect(x: canvas.minX + 51 * scale,
                          y: canvas.minY + 21 * scale,
                          width: size.width, height: size.height + breath)
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1,
                   respectFlipped: true, hints: nil)
    }

    /// Bounds of the normal pose within the larger action canvas.
    var standingRect: NSRect {
        let scale = min(bounds.width / 226, bounds.height / 213)
        return NSRect(x: bounds.midX - 62 * scale,
                      y: bounds.midY - 85.5 * scale,
                      width: 127 * scale, height: 142 * scale)
    }

    private static var resources: Bundle {
        // SwiftPM's generated accessor looks beside the executable or in the build
        // tree. App bundles must resolve their embedded resources independently.
        if let url = Bundle.main.url(forResource: "WaddleOn_WaddleOn", withExtension: "bundle"),
           let embedded = Bundle(url: url) {
            return embedded
        } else {
            return Bundle.module
        }
    }

    private static func loadActionFrames(_ name: String, columns: Int, rows: Int, count: Int) -> [NSImage] {
        guard let url = resources.url(forResource: "penguin-\(name)-atlas", withExtension: "png",
                                      subdirectory: "Resources/Penguin"),
              let image = NSImage(contentsOf: url),
              let atlas = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
              atlas.width == columns * 226, atlas.height == rows * 213 else {
            NSLog("Waddle On: missing or invalid penguin-\(name)-atlas.png")
            return []
        }
        return (0..<count).compactMap { index in
            guard let cell = atlas.cropping(to: CGRect(x: index % columns * 226,
                                                       y: index / columns * 213,
                                                       width: 226, height: 213)) else { return nil }
            return NSImage(cgImage: cell, size: NSSize(width: 226, height: 213))
        }
    }

    private static func loadFrames() -> [[NSImage]] {
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
