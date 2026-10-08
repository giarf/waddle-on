import AppKit

// Monochrome vector adaptation of the user's igloo reference.
func path(_ draw: (NSBezierPath) -> Void) -> NSBezierPath {
    let p = NSBezierPath(); draw(p); p.close(); return p
}
let dome = path { p in
    p.move(to: .init(x: 25, y: 290))
    p.curve(to: .init(x: 280, y: 15), controlPoint1: .init(x: 5, y: 115), controlPoint2: .init(x: 130, y: 10))
    p.curve(to: .init(x: 515, y: 260), controlPoint1: .init(x: 445, y: 10), controlPoint2: .init(x: 515, y: 115))
    p.curve(to: .init(x: 260, y: 433), controlPoint1: .init(x: 535, y: 370), controlPoint2: .init(x: 395, y: 435))
    p.curve(to: .init(x: 25, y: 290), controlPoint1: .init(x: 125, y: 435), controlPoint2: .init(x: 30, y: 375))
}
let shade = path { p in
    p.move(to: .init(x: 280, y: 15))
    p.curve(to: .init(x: 350, y: 245), controlPoint1: .init(x: 340, y: 100), controlPoint2: .init(x: 375, y: 175))
    p.curve(to: .init(x: 278, y: 430), controlPoint1: .init(x: 400, y: 345), controlPoint2: .init(x: 305, y: 415))
    p.curve(to: .init(x: 515, y: 260), controlPoint1: .init(x: 435, y: 425), controlPoint2: .init(x: 535, y: 365))
    p.curve(to: .init(x: 280, y: 15), controlPoint1: .init(x: 515, y: 110), controlPoint2: .init(x: 435, y: 15))
}
let tunnel = path { p in
    p.move(to: .init(x: 55, y: 278))
    p.curve(to: .init(x: 147, y: 214), controlPoint1: .init(x: 75, y: 240), controlPoint2: .init(x: 115, y: 222))
    p.curve(to: .init(x: 273, y: 435), controlPoint1: .init(x: 265, y: 214), controlPoint2: .init(x: 302, y: 327))
    p.line(to: .init(x: 222, y: 488)); p.line(to: .init(x: 188, y: 475))
    p.line(to: .init(x: 58, y: 425)); p.line(to: .init(x: 14, y: 405))
    p.curve(to: .init(x: 55, y: 278), controlPoint1: .init(x: 20, y: 354), controlPoint2: .init(x: 38, y: 302))
}
let front = path { p in
    p.move(to: .init(x: 14, y: 405))
    p.curve(to: .init(x: 96, y: 263), controlPoint1: .init(x: 30, y: 294), controlPoint2: .init(x: 52, y: 252))
    p.curve(to: .init(x: 222, y: 488), controlPoint1: .init(x: 218, y: 282), controlPoint2: .init(x: 260, y: 355))
    p.line(to: .init(x: 188, y: 475))
    p.curve(to: .init(x: 115, y: 320), controlPoint1: .init(x: 213, y: 365), controlPoint2: .init(x: 169, y: 330))
    p.curve(to: .init(x: 58, y: 425), controlPoint1: .init(x: 72, y: 300), controlPoint2: .init(x: 65, y: 384))
}

func render(size: Int, template: Bool) -> NSBitmapImageRep {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let context = NSGraphicsContext.current!.cgContext
    context.translateBy(x: 0, y: CGFloat(size))
    context.scaleBy(x: CGFloat(size)/1024, y: -CGFloat(size)/1024)
    if !template {
        NSColor(white: 0.93, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 42, y: 42, width: 940, height: 940), xRadius: 208, yRadius: 208).fill()
        context.translateBy(x: 110, y: 145); context.scaleBy(x: 1.5, y: 1.5)
    } else {
        context.translateBy(x: 30, y: 58); context.scaleBy(x: 1.8, y: 1.8)
    }
    func paint(_ shape: NSBezierPath, white: CGFloat) {
        if template {
            context.setBlendMode(.destinationOut)
            NSColor.black.setFill(); shape.fill()
            context.setBlendMode(.normal)
        } else {
            NSColor(white: white, alpha: 1).setFill(); shape.fill()
        }
        NSColor.black.setStroke(); shape.lineWidth = template ? 24 : 22
        shape.lineJoinStyle = .round; shape.stroke()
    }
    paint(dome, white: 1)
    if !template { NSColor(white: 0.77, alpha: 1).setFill(); shade.fill() }
    paint(tunnel, white: 0.7)
    paint(front, white: 1)
    return bitmap
}

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let iconset = root.appendingPathComponent("build/WaddleOn.iconset")
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try render(size: size * scale, template: false).representation(using: .png, properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
try render(size: 1024, template: false).representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Support/AppIcon.png"))
try render(size: 72, template: true).representation(using: .png, properties: [:])!.write(to: root.appendingPathComponent("Sources/WaddleOn/Resources/MenuIcon.png"))
