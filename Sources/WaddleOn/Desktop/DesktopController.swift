import AppKit

/// Owns the desktop presentation. Call its API on the main thread.
final class DesktopController: NSObject {
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?
    var snowballsEnabled = true {
        didSet {
            scheduleSnowball()
            if !snowballsEnabled { cancelSnowball() }
        }
    }
    var snowballInterval: Double = 20 {
        didSet {
            snowballInterval = SnowballTrajectory.clampedInterval(snowballInterval)
            scheduleSnowball()
        }
    }
    var followsMouse = true {
        didSet {
            destination = nil
            movementOrigin = nil
            penguin?.setWalking(false, toward: .zero)
        }
    }

    private let characterSize = NSSize(width: 267, height: 252)
    private let feetOffset: CGFloat = 41
    private var characterPanel: DesktopPanel!
    private var characterHost: CharacterDragView!
    private var penguin: PenguinView!
    private var chatPanel: DesktopPanel!
    private var bubblePanel: DesktopPanel!
    private var bubbleText: NSTextView!
    private var bubbleMath: MathMessageWebView!
    private var statusItem: NSStatusItem?
    private var visibilityItem: NSMenuItem?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var timer: Timer?
    private var danceHotKey: DanceHotKey?
    private var nextSnowball: TimeInterval?
    private var pendingThrow: (launchTime: TimeInterval, start: NSPoint, target: NSPoint)?
    private var throwingUntil: TimeInterval?
    private var projectile: SnowballProjectile?
    private var menuTracking = false
    private var screenObserver: NSObjectProtocol?
    private var destination: NSPoint?
    // Preserve subpixel progress instead of feeding NSWindow's rounded frame
    // back into the next step (negative steps otherwise accumulate faster).
    private var movementOrigin: NSPoint?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var walkingStartsAt: TimeInterval = 0
    private var lastHitCheck: TimeInterval = 0
    private var started = false
    private var visible = true
    private var chatVisible = false
    private var welcomeVisible = true
    private var awaitingFirstFollow = true
    private var chatExpanded = false
    private var bubbleVisible = false
    private var bubbleMeasuredWidth: CGFloat = 0
    private var bubbleMeasuredText = ""
    private var bubbleMeasuredHeight: CGFloat = 0

    override init() {
        super.init()
        makePanels()
    }

    func start() {
        guard !started else { return }
        penguin.prepareAnimations()
        started = true
        visible = true
        placeInitially()
        chatVisible = false
        welcomeVisible = true
        awaitingFirstFollow = true
        penguin.toggleDance()
        makeMenu()
        danceHotKey = DanceHotKey { [weak self] in self?.toggleDance() }
        scheduleSnowball()
        // Mouse-only observation does not require Accessibility or Input Monitoring.
        // No event tap or global keyboard capture is installed.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleOptionClick(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { [weak self] event in
            self?.handleOptionClick(event)
            return event
        }
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in self?.screensChanged() }
        lastTick = ProcessInfo.processInfo.systemUptime
        let timer = Timer(timeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in self?.tick() }
        self.timer = timer
        RunLoop.main.add(timer, forMode: .common)
        updateVisibility()
        walkingStartsAt = ProcessInfo.processInfo.systemUptime + 5
    }

    func stop() {
        started = false
        stopActions()
        nextSnowball = nil
        danceHotKey?.stop()
        danceHotKey = nil
        timer?.invalidate()
        timer = nil
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
        destination = nil
        penguin.setWalking(false, toward: .zero)
        characterPanel.orderOut(nil)
        chatPanel.orderOut(nil)
        bubblePanel.orderOut(nil)
        if let statusItem { NSStatusBar.system.removeStatusItem(statusItem) }
        statusItem = nil
    }

    func showBubble(_ text: String) {
        welcomeVisible = false
        bubbleText.string = text
        bubbleMath.setMessage(text)
        bubbleVisible = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        positionCompanions()
        updateVisibility()
    }

    func showWelcome() {
        showBubble("⌥ + D para que te siga\nHaz clic en mí para hablarme.")
        welcomeVisible = true
        updateVisibility()
    }

    func setChatVisible(_ visible: Bool) {
        welcomeVisible = false
        chatVisible = visible
        if visible { self.visible = true }
        positionCompanions()
        updateVisibility()
        if visible, started {
            NSApp.activate(ignoringOtherApps: true)
            chatPanel.makeKeyAndOrderFront(nil)
        }
    }

    func setChatContent(_ view: NSView) {
        chatPanel.contentView = view
        view.frame = NSRect(origin: .zero, size: chatPanel.frame.size)
        view.autoresizingMask = [.width, .height]
    }

    func setChatExpanded(_ expanded: Bool) {
        chatExpanded = expanded
        positionCompanions()
    }

    private func makePanels() {
        characterPanel = makePanel(size: characterSize)
        characterPanel.ignoresMouseEvents = true
        characterHost = CharacterDragView(frame: NSRect(origin: .zero, size: characterSize))
        penguin = PenguinView(frame: characterHost.bounds)
        penguin.autoresizingMask = [.width, .height]
        characterHost.addSubview(penguin)
        characterHost.onDragStart = { [weak self] in
            self?.stopActions()
            self?.scheduleSnowball()
            self?.destination = nil
            self?.movementOrigin = nil
            self?.penguin.setWalking(false, toward: .zero)
        }
        characterHost.onDrag = { [weak self] delta in
            guard let self else { return }
            let origin = self.characterPanel.frame.origin
            self.characterPanel.setFrameOrigin(NSPoint(x: origin.x + delta.x, y: origin.y + delta.y))
            self.positionCompanions()
        }
        characterHost.onDragEnd = { [weak self] in self?.screensChanged() }
        characterHost.onClick = { [weak self] in
            guard let self else { return }
            self.setChatVisible(!self.chatVisible)
        }
        characterPanel.contentView = characterHost

        chatPanel = makePanel(size: NSSize(width: 660, height: 100), acceptsKey: true)
        chatPanel.hasShadow = true

        bubblePanel = makePanel(size: NSSize(width: 320, height: 100))
        bubblePanel.ignoresMouseEvents = false
        bubblePanel.hasShadow = true
        let background = SpeechBubbleView(frame: NSRect(x: 0, y: 0, width: 320, height: 100))
        background.autoresizingMask = [.width, .height]
        let scroll = NSScrollView(frame: NSRect(x: 14, y: 24, width: 292, height: 64))
        scroll.autoresizingMask = [.width, .height]
        scroll.drawsBackground = false
        scroll.hasVerticalScroller = true
        scroll.autohidesScrollers = true
        bubbleText = NSTextView(frame: NSRect(x: 0, y: 0, width: 292, height: 76))
        bubbleText.isEditable = false
        bubbleText.isSelectable = true
        bubbleText.drawsBackground = false
        bubbleText.font = .systemFont(ofSize: 14)
        bubbleText.textColor = .labelColor
        bubbleText.textContainerInset = .zero
        bubbleText.isVerticallyResizable = true
        bubbleText.isHorizontallyResizable = false
        bubbleText.autoresizingMask = [.width]
        bubbleText.textContainer?.widthTracksTextView = true
        scroll.documentView = bubbleText
        bubbleMath = MathMessageWebView()
        bubbleMath.frame = scroll.frame
        bubbleMath.autoresizingMask = [.width, .height]
        bubbleMath.onHeight = { [weak self] height in
            guard let self else { return }
            self.bubbleMeasuredHeight = height
            self.positionCompanions()
        }
        background.addSubview(bubbleMath)
        bubblePanel.contentView = background
    }

    private func makePanel(size: NSSize, acceptsKey: Bool = false) -> DesktopPanel {
        let panel = DesktopPanel(contentRect: NSRect(origin: .zero, size: size),
                                 styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        panel.acceptsKey = acceptsKey
        panel.level = .floating
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.isReleasedWhenClosed = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovableByWindowBackground = false
        return panel
    }

    private func placeInitially() {
        movementOrigin = nil
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        characterPanel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - characterSize.width - 40,
                                             y: screen.visibleFrame.minY + 125))
        positionCompanions()
    }

    private func handleOptionClick(_ event: NSEvent) {
        guard !followsMouse, event.modifierFlags.contains(.option), started else { return }
        visible = true
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) else { return }
        // Mouse location and NSWindow origins both use global AppKit coordinates,
        // including negative origins on secondary displays.
        destination = clampedOrigin(NSPoint(x: point.x - characterSize.width / 2,
                                            y: point.y - feetOffset), on: screen)
        updateVisibility()
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(now - lastTick, 0.05)
        lastTick = now
        penguin.advanceAnimation(at: now)
        let readyToWalk = now >= walkingStartsAt && !awaitingFirstFollow
        if readyToWalk { updateActions(now: now) }
        let actionBlocksWalking = penguin.isPerformingAction || pendingThrow != nil || throwingUntil != nil
        if readyToWalk, followsMouse, !actionBlocksWalking { updateMouseDestination() }
        if let target = destination, readyToWalk, visible, !characterHost.isDragging, !actionBlocksWalking {
            let origin = movementOrigin ?? characterPanel.frame.origin
            let dx = target.x - origin.x
            let dy = target.y - origin.y
            let distance = hypot(dx, dy)
            let step = CGFloat(elapsed) * (followsMouse ? 110 : 300)
            if distance <= max(step, 0.5) {
                movementOrigin = target
                characterPanel.setFrameOrigin(target)
                destination = nil
                penguin.setWalking(false, toward: .zero)
            } else {
                penguin.setWalking(true, toward: CGVector(dx: dx, dy: dy))
                let next = NSPoint(x: origin.x + dx / distance * step,
                                   y: origin.y + dy / distance * step)
                movementOrigin = next
                characterPanel.setFrameOrigin(next)
            }
            positionCompanions()
        } else if !actionBlocksWalking {
            movementOrigin = nil
        }
        if now - lastHitCheck >= 0.05 {
            lastHitCheck = now
            updateCharacterHitRegion()
            if chatVisible { updatePanelHitRegion(chatPanel) }
            if (chatVisible || welcomeVisible) && bubbleVisible { updatePanelHitRegion(bubblePanel) }
        }
    }

    private func updateMouseDestination() {
        let point = NSEvent.mouseLocation
        // Stay still while the user interacts with our UI or drags anything.
        let interacting = NSApp.windows.contains {
            $0.isVisible && $0 !== characterPanel && $0 !== projectile?.panel && $0.frame.contains(point)
        }
        guard visible, !characterHost.isDragging, NSEvent.pressedMouseButtons == 0,
              !interacting,
              let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) else {
            destination = nil
            penguin.setWalking(false, toward: .zero)
            return
        }
        let origin = movementOrigin ?? characterPanel.frame.origin
        let feet = NSPoint(x: origin.x + characterSize.width / 2, y: origin.y + feetOffset)
        let dx = point.x - feet.x
        let dy = point.y - feet.y
        let distance = hypot(dx, dy)
        // Hysteresis avoids little steps every time the cursor trembles.
        let stoppingDistance: CGFloat = 110
        guard distance > (destination == nil ? stoppingDistance + 30 : stoppingDistance + 2) else {
            destination = nil
            penguin.setWalking(false, toward: .zero)
            return
        }
        destination = clampedOrigin(NSPoint(
            x: point.x - dx / distance * stoppingDistance - characterSize.width / 2,
            y: point.y - dy / distance * stoppingDistance - feetOffset
        ), on: screen)
    }

    private func updatePanelHitRegion(_ panel: NSPanel) {
        // Keep receiving mouse-up during selection and scroll interactions.
        guard NSEvent.pressedMouseButtons == 0, let content = panel.contentView else { return }
        // WebKit draws out of process and does not appear in cacheDisplay.
        if panel === bubblePanel {
            panel.ignoresMouseEvents = !panel.frame.insetBy(dx: 5, dy: 5).contains(NSEvent.mouseLocation)
            return
        }
        let local = content.convert(panel.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
        guard content.bounds.contains(local), let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds) else {
            panel.ignoresMouseEvents = true
            return
        }
        content.cacheDisplay(in: content.bounds, to: bitmap)
        let x = min(bitmap.pixelsWide - 1, max(0, Int(local.x / content.bounds.width * CGFloat(bitmap.pixelsWide))))
        let fraction = local.y / content.bounds.height
        let y = min(bitmap.pixelsHigh - 1, max(0, Int((content.isFlipped ? fraction : 1 - fraction) * CGFloat(bitmap.pixelsHigh))))
        panel.ignoresMouseEvents = (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) < 0.08
    }

    private func updateCharacterHitRegion() {
        guard visible, !characterHost.isDragging else { return }
        let mouse = NSEvent.mouseLocation
        let hostPoint = NSPoint(x: mouse.x - characterPanel.frame.minX, y: mouse.y - characterPanel.frame.minY)
        let local = penguin.convert(hostPoint, from: characterHost)
        guard penguin.bounds.contains(local),
              let bitmap = penguin.bitmapImageRepForCachingDisplay(in: penguin.bounds) else {
            characterPanel.ignoresMouseEvents = true
            return
        }
        // Test the rendered sprite's alpha, rather than its rectangular window.
        // Transparent corners therefore pass clicks to the application below.
        bitmap.size = penguin.bounds.size
        penguin.cacheDisplay(in: penguin.bounds, to: bitmap)
        let x = min(bitmap.pixelsWide - 1, max(0, Int(local.x / penguin.bounds.width * CGFloat(bitmap.pixelsWide))))
        let normalizedY = local.y / penguin.bounds.height
        let bitmapY = penguin.isFlipped ? normalizedY : 1 - normalizedY
        let y = min(bitmap.pixelsHigh - 1, max(0, Int(bitmapY * CGFloat(bitmap.pixelsHigh))))
        characterPanel.ignoresMouseEvents = (bitmap.colorAt(x: x, y: y)?.alphaComponent ?? 0) < 0.08
    }

    private var characterScreen: NSScreen? {
        let center = NSPoint(x: characterPanel.frame.midX, y: characterPanel.frame.midY)
        return NSScreen.screens.first(where: { $0.frame.contains(center) }) ?? NSScreen.main ?? NSScreen.screens.first
    }

    private func clampedOrigin(_ point: NSPoint, on screen: NSScreen) -> NSPoint {
        let bounds = screen.visibleFrame
        return NSPoint(x: min(max(point.x, bounds.minX), max(bounds.minX, bounds.maxX - characterSize.width)),
                       y: min(max(point.y, bounds.minY), max(bounds.minY, bounds.maxY - characterSize.height)))
    }

    private func screensChanged() {
        movementOrigin = nil
        guard let screen = characterScreen else { return }
        destination = nil
        penguin.setWalking(false, toward: .zero)
        characterPanel.setFrameOrigin(clampedOrigin(characterPanel.frame.origin, on: screen))
        positionCompanions()
    }

    private func positionCompanions() {
        guard let screen = characterScreen else { return }
        let bounds = screen.visibleFrame.insetBy(dx: 12, dy: 12)
        let width = min(CGFloat(660), bounds.width)
        let height = min(chatExpanded ? CGFloat(450) : 100, bounds.height)
        chatPanel.setFrame(NSRect(x: bounds.midX - width / 2, y: bounds.minY, width: width, height: height), display: true)

        let bubbleWidth = min(CGFloat(340), bounds.width)
        let contentWidth = max(1, bubbleWidth - 38)
        if bubbleMeasuredText != bubbleText.string || bubbleMeasuredWidth != contentWidth {
            bubbleMeasuredText = bubbleText.string
            bubbleMeasuredWidth = contentWidth
            bubbleMeasuredHeight = ceil((bubbleText.string as NSString).boundingRect(
                with: NSSize(width: contentWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading],
                attributes: [.font: NSFont.systemFont(ofSize: 14)]).height)
        }
        let bubbleHeight = min(max(76, bubbleMeasuredHeight + 42), min(280, bounds.height))
        let x = min(max(characterPanel.frame.midX - bubbleWidth / 2, bounds.minX), bounds.maxX - bubbleWidth)
        let pose = characterPanel.convertToScreen(penguin.convert(penguin.standingRect, to: nil))
        var y = pose.maxY + 4
        if y + bubbleHeight > bounds.maxY { y = pose.minY - bubbleHeight - 4 }
        y = min(max(y, bounds.minY), bounds.maxY - bubbleHeight)
        bubblePanel.setFrame(NSRect(x: x, y: y, width: bubbleWidth, height: bubbleHeight), display: true)
        bubbleText.textContainer?.containerSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)
        bubbleText.setFrameSize(NSSize(width: contentWidth, height: max(bubbleHeight - 36, bubbleMeasuredHeight + 8)))
    }

    private func updateVisibility() {
        visibilityItem?.title = visible ? "Ocultar Waddle On" : "Mostrar Waddle On"
        guard started, visible else {
            stopActions()
            nextSnowball = nil
            characterPanel.orderOut(nil)
            chatPanel.orderOut(nil)
            bubblePanel.orderOut(nil)
            return
        }
        characterPanel.orderFrontRegardless()
        if nextSnowball == nil { scheduleSnowball() }
        if chatVisible { chatPanel.orderFrontRegardless() } else { chatPanel.orderOut(nil) }
        if (chatVisible || welcomeVisible) && bubbleVisible { bubblePanel.orderFrontRegardless() } else { bubblePanel.orderOut(nil) }
    }

    private func makeMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let embedded = Bundle.main.url(forResource: "WaddleOn_WaddleOn", withExtension: "bundle").flatMap(Bundle.init(url:))
        if let url = (embedded ?? Bundle.module).url(forResource: "MenuIcon", withExtension: "png", subdirectory: "Resources"),
           let image = NSImage(contentsOf: url) {
            image.size = NSSize(width: 20, height: 20)
            image.isTemplate = true
            item.button?.image = image
        } else {
            item.button?.image = NSImage(systemSymbolName: "bird.fill", accessibilityDescription: "Waddle On")
        }
        item.button?.toolTip = "Waddle On — Opción + clic para caminar"
        let menu = NSMenu()
        menu.delegate = self
        visibilityItem = menu.addItem(withTitle: "Ocultar Waddle On", action: #selector(toggleVisibility), keyEquivalent: "")
        visibilityItem?.target = self
        addMenuItem("Abrir chat", action: #selector(openChat), to: menu)
        addMenuItem("Traer pingüino aquí", action: #selector(bringHere), to: menu)
        addMenuItem("Bailar / dejar de bailar (⌥D)", action: #selector(toggleDance), to: menu)
        menu.addItem(.separator())
        let hint = menu.addItem(withTitle: "Opción + clic para caminar · Arrastra para mover", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(.separator())
        addMenuItem("Configuración…", action: #selector(openSettings), to: menu)
        addMenuItem("Salir de Waddle On", action: #selector(quit), to: menu)
        item.menu = menu
        statusItem = item
    }

    private func addMenuItem(_ title: String, action: Selector, to menu: NSMenu) {
        menu.addItem(withTitle: title, action: action, keyEquivalent: "").target = self
    }

    @objc private func toggleVisibility() {
        visible.toggle()
        if !visible { destination = nil; penguin.setWalking(false, toward: .zero) }
        updateVisibility()
    }
    @objc private func openChat() { setChatVisible(true) }
    @objc private func openSettings() { stopActions(); scheduleSnowball(); onOpenSettings?() }
    @objc private func quit() {
        if let onQuit { onQuit() } else { NSApp.terminate(nil) }
    }
    @objc private func bringHere() {
        stopActions()
        visible = true
        placeInitially()
        destination = nil
        penguin.setWalking(false, toward: .zero)
        updateVisibility()
    }

    /// A registered global shortcut and the menu share this action.
    @objc func toggleDance() {
        guard started, visible, !characterHost.isDragging, !settingsVisible else { return }
        if awaitingFirstFollow {
            awaitingFirstFollow = false
            followsMouse = true
            stopActions()
            walkingStartsAt = ProcessInfo.processInfo.systemUptime
            scheduleSnowball()
            return
        }
        cancelSnowball()
        penguin.setWalking(false, toward: .zero)
        penguin.toggleDance()
        scheduleSnowball()
    }

    private var settingsVisible: Bool {
        NSApp.windows.contains { $0.isVisible && $0.styleMask.contains(.titled) }
    }

    private var actionInteraction: Bool {
        if characterHost.isDragging || NSEvent.pressedMouseButtons != 0 || menuTracking || settingsVisible { return true }
        let point = NSEvent.mouseLocation
        return NSApp.windows.contains {
            $0.isVisible && $0 !== characterPanel && $0 !== projectile?.panel && $0.frame.contains(point)
        }
    }

    private func scheduleSnowball() {
        nextSnowball = ProcessInfo.processInfo.systemUptime
            + SnowballTrajectory.randomDelay(interval: snowballInterval)
    }

    private func cancelSnowball() {
        if pendingThrow != nil || throwingUntil != nil { penguin?.stopAction() }
        pendingThrow = nil
        throwingUntil = nil
        projectile?.stop()
        projectile = nil
    }

    private func stopActions() {
        cancelSnowball()
        penguin?.stopAction()
    }

    private func updateActions(now: TimeInterval) {
        guard started, visible else { return }
        if let throwingUntil, now >= throwingUntil { self.throwingUntil = nil }
        if let projectile, !projectile.advance(now: now) {
            projectile.stop()
            self.projectile = nil
        }
        if actionInteraction {
            if pendingThrow != nil { cancelSnowball() }
            if settingsVisible { stopActions() }
            scheduleSnowball()
            return
        }
        if let pending = pendingThrow, now >= pending.launchTime {
            projectile?.stop()
            projectile = SnowballProjectile(start: pending.start, target: pending.target, launchedAt: now)
            pendingThrow = nil
        }
        guard snowballsEnabled, !penguin.isPerformingAction, pendingThrow == nil, projectile == nil,
              let deadline = nextSnowball, now >= deadline else { return }
        // Capture once: moving the pointer during the wind-up never retargets the throw.
        let target = NSEvent.mouseLocation
        let start = NSPoint(x: characterPanel.frame.midX, y: characterPanel.frame.minY + feetOffset + 71)
        penguin.setWalking(false, toward: .zero)
        penguin.throwSnowball(toward: CGVector(dx: target.x - start.x, dy: target.y - start.y))
        pendingThrow = (now + PenguinView.snowballReleaseDelay, start, target)
        throwingUntil = now + PenguinView.throwDuration
        scheduleSnowball()
    }
}

extension DesktopController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) { menuTracking = true; cancelSnowball() }
    func menuDidClose(_ menu: NSMenu) { menuTracking = false; scheduleSnowball() }
}

private final class DesktopPanel: NSPanel {
    var acceptsKey = false
    override var canBecomeKey: Bool { acceptsKey }
    override var canBecomeMain: Bool { false }
}

private final class SpeechBubbleView: NSView {
    override func draw(_ dirtyRect: NSRect) {
        let body = NSBezierPath(roundedRect: NSRect(x: 1, y: 13, width: bounds.width - 2,
                                                   height: bounds.height - 14), xRadius: 16, yRadius: 16)
        NSColor.controlBackgroundColor.setFill()
        body.fill()
        NSColor(calibratedRed: 0.12, green: 0.35, blue: 0.52, alpha: 1).setStroke()
        body.lineWidth = 2
        body.stroke()
        let tail = NSBezierPath()
        tail.move(to: NSPoint(x: bounds.midX - 11, y: 14))
        tail.line(to: NSPoint(x: bounds.midX, y: 2))
        tail.line(to: NSPoint(x: bounds.midX + 11, y: 14))
        tail.close()
        NSColor.controlBackgroundColor.setFill()
        tail.fill()
        let edge = NSBezierPath()
        edge.move(to: NSPoint(x: bounds.midX - 11, y: 13))
        edge.line(to: NSPoint(x: bounds.midX, y: 2))
        edge.line(to: NSPoint(x: bounds.midX + 11, y: 13))
        edge.lineWidth = 2
        edge.stroke()
    }
}

private final class CharacterDragView: NSView {
    var onDragStart: (() -> Void)?
    var onDrag: ((NSPoint) -> Void)?
    var onDragEnd: (() -> Void)?
    var onClick: (() -> Void)?
    private(set) var isDragging = false
    private var lastMouse = NSPoint.zero
    private var moved = false
    private var optionClick = false

    override func hitTest(_ point: NSPoint) -> NSView? { bounds.contains(point) ? self : nil }
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
    override func mouseDown(with event: NSEvent) {
        optionClick = event.modifierFlags.contains(.option)
        guard !optionClick else { return }
        isDragging = true
        moved = false
        lastMouse = NSEvent.mouseLocation
        onDragStart?()
    }
    override func mouseDragged(with event: NSEvent) {
        guard isDragging else { return }
        let current = NSEvent.mouseLocation
        let delta = NSPoint(x: current.x - lastMouse.x, y: current.y - lastMouse.y)
        if abs(delta.x) + abs(delta.y) > 0 { moved = true }
        onDrag?(delta)
        lastMouse = current
    }
    override func mouseUp(with event: NSEvent) {
        guard !optionClick else { optionClick = false; return }
        isDragging = false
        if moved { onDragEnd?() } else { onClick?() }
    }
}
