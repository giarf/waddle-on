import AppKit

/// Owns the desktop presentation. Call its API on the main thread.
final class DesktopController: NSObject {
    var onOpenSettings: (() -> Void)?
    var onQuit: (() -> Void)?

    private let characterSize = NSSize(width: 150, height: 170)
    private var characterPanel: DesktopPanel!
    private var characterHost: CharacterDragView!
    private var penguin: PenguinView!
    private var chatPanel: DesktopPanel!
    private var bubblePanel: DesktopPanel!
    private var bubbleText: NSTextView!
    private var statusItem: NSStatusItem?
    private var visibilityItem: NSMenuItem?
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var timer: Timer?
    private var screenObserver: NSObjectProtocol?
    private var destination: NSPoint?
    private var lastTick = ProcessInfo.processInfo.systemUptime
    private var lastHitCheck: TimeInterval = 0
    private var started = false
    private var visible = true
    private var chatVisible = true
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
        started = true
        visible = true
        placeInitially()
        makeMenu()
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
    }

    func stop() {
        started = false
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
        bubbleText.string = text
        bubbleVisible = !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        positionCompanions()
        updateVisibility()
    }

    func setChatVisible(_ visible: Bool) {
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
            self?.destination = nil
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
        background.addSubview(scroll)
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
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        characterPanel.setFrameOrigin(NSPoint(x: screen.visibleFrame.maxX - characterSize.width - 40,
                                             y: screen.visibleFrame.minY + 125))
        positionCompanions()
    }

    private func handleOptionClick(_ event: NSEvent) {
        guard event.modifierFlags.contains(.option), started else { return }
        visible = true
        let point = NSEvent.mouseLocation
        guard let screen = NSScreen.screens.first(where: { $0.frame.contains(point) }) else { return }
        // Mouse location and NSWindow origins both use global AppKit coordinates,
        // including negative origins on secondary displays.
        destination = clampedOrigin(NSPoint(x: point.x - characterSize.width / 2,
                                            y: point.y - 14), on: screen)
        updateVisibility()
    }

    private func tick() {
        let now = ProcessInfo.processInfo.systemUptime
        let elapsed = min(now - lastTick, 0.05)
        lastTick = now
        if let target = destination, visible, !characterHost.isDragging {
            let origin = characterPanel.frame.origin
            let dx = target.x - origin.x
            let dy = target.y - origin.y
            let distance = hypot(dx, dy)
            let step = CGFloat(elapsed) * 300
            if distance <= max(step, 0.5) {
                characterPanel.setFrameOrigin(target)
                destination = nil
                penguin.setWalking(false, toward: .zero)
            } else {
                penguin.setWalking(true, toward: CGVector(dx: dx, dy: dy))
                characterPanel.setFrameOrigin(NSPoint(x: origin.x + dx / distance * step,
                                                       y: origin.y + dy / distance * step))
            }
            positionCompanions()
        }
        if now - lastHitCheck >= 0.05 {
            lastHitCheck = now
            updateCharacterHitRegion()
            if chatVisible { updatePanelHitRegion(chatPanel) }
            if bubbleVisible { updatePanelHitRegion(bubblePanel) }
        }
    }

    private func updatePanelHitRegion(_ panel: NSPanel) {
        // Keep receiving mouse-up during selection and scroll interactions.
        guard NSEvent.pressedMouseButtons == 0, let content = panel.contentView else { return }
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
        var y = characterPanel.frame.maxY + 8
        if y + bubbleHeight > bounds.maxY { y = characterPanel.frame.minY - bubbleHeight - 8 }
        y = min(max(y, bounds.minY), bounds.maxY - bubbleHeight)
        bubblePanel.setFrame(NSRect(x: x, y: y, width: bubbleWidth, height: bubbleHeight), display: true)
        bubbleText.textContainer?.containerSize = NSSize(width: contentWidth, height: .greatestFiniteMagnitude)
        bubbleText.setFrameSize(NSSize(width: contentWidth, height: max(bubbleHeight - 36, bubbleMeasuredHeight + 8)))
    }

    private func updateVisibility() {
        visibilityItem?.title = visible ? "Ocultar Waddle On" : "Mostrar Waddle On"
        guard started, visible else {
            characterPanel.orderOut(nil)
            chatPanel.orderOut(nil)
            bubblePanel.orderOut(nil)
            return
        }
        characterPanel.orderFrontRegardless()
        if chatVisible { chatPanel.orderFrontRegardless() } else { chatPanel.orderOut(nil) }
        if bubbleVisible { bubblePanel.orderFrontRegardless() } else { bubblePanel.orderOut(nil) }
    }

    private func makeMenu() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.title = "🐧"
        item.button?.toolTip = "Waddle On — Opción + clic para caminar"
        let menu = NSMenu()
        visibilityItem = menu.addItem(withTitle: "Ocultar Waddle On", action: #selector(toggleVisibility), keyEquivalent: "")
        visibilityItem?.target = self
        addMenuItem("Abrir chat", action: #selector(openChat), to: menu)
        addMenuItem("Traer pingüino aquí", action: #selector(bringHere), to: menu)
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
    @objc private func openSettings() { onOpenSettings?() }
    @objc private func quit() {
        if let onQuit { onQuit() } else { NSApp.terminate(nil) }
    }
    @objc private func bringHere() {
        visible = true
        placeInitially()
        destination = nil
        penguin.setWalking(false, toward: .zero)
        updateVisibility()
    }
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
