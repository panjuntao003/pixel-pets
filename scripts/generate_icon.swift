import AppKit
import Foundation

struct IconImage {
    let filename: String
    let idiom: String
    let size: Int
    let scale: Int

    var pixels: Int { size * scale }
}

let output = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    .appendingPathComponent("Quota/Assets.xcassets/AppIcon.appiconset")

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

let images = [
    IconImage(filename: "icon_16.png", idiom: "mac", size: 16, scale: 1),
    IconImage(filename: "icon_16@2x.png", idiom: "mac", size: 16, scale: 2),
    IconImage(filename: "icon_32.png", idiom: "mac", size: 32, scale: 1),
    IconImage(filename: "icon_32@2x.png", idiom: "mac", size: 32, scale: 2),
    IconImage(filename: "icon_128.png", idiom: "mac", size: 128, scale: 1),
    IconImage(filename: "icon_128@2x.png", idiom: "mac", size: 128, scale: 2),
    IconImage(filename: "icon_256.png", idiom: "mac", size: 256, scale: 1),
    IconImage(filename: "icon_256@2x.png", idiom: "mac", size: 256, scale: 2),
    IconImage(filename: "icon_512.png", idiom: "mac", size: 512, scale: 1),
    IconImage(filename: "icon_512@2x.png", idiom: "mac", size: 512, scale: 2)
]

func drawIcon(size pixels: Int) -> NSImage {
    let image = NSImage(size: NSSize(width: pixels, height: pixels))
    image.lockFocus()

    let rect = NSRect(x: 0, y: 0, width: pixels, height: pixels)
    NSColor(red: 0.11, green: 0.11, blue: 0.12, alpha: 1.0).setFill()
    NSBezierPath(roundedRect: rect, xRadius: CGFloat(pixels) * 0.22, yRadius: CGFloat(pixels) * 0.22).fill()

    let lineWidth = max(2.0, CGFloat(pixels) * 0.075)
    let inset = CGFloat(pixels) * 0.23
    let arcRect = rect.insetBy(dx: inset, dy: inset)
    let arc = NSBezierPath()
    arc.lineWidth = lineWidth
    arc.lineCapStyle = .round
    arc.appendArc(withCenter: NSPoint(x: rect.midX, y: rect.midY),
                  radius: arcRect.width / 2,
                  startAngle: 130,
                  endAngle: 405)
    NSColor.white.setStroke()
    arc.stroke()

    let dotRadius = CGFloat(pixels) * 0.055
    NSColor(red: 1.0, green: 0.80, blue: 0.0, alpha: 1.0).setFill()
    NSBezierPath(ovalIn: NSRect(x: rect.midX + CGFloat(pixels) * 0.18,
                                y: rect.midY - CGFloat(pixels) * 0.31,
                                width: dotRadius * 2,
                                height: dotRadius * 2)).fill()

    image.unlockFocus()
    return image
}

for image in images {
    let url = output.appendingPathComponent(image.filename)
    guard let tiff = drawIcon(size: image.pixels).tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw NSError(domain: "IconGeneration", code: 1)
    }
    try png.write(to: url)
}

let contents: [String: Any] = [
    "images": images.map {
        [
            "filename": $0.filename,
            "idiom": $0.idiom,
            "scale": "\($0.scale)x",
            "size": "\($0.size)x\($0.size)"
        ]
    },
    "info": [
        "author": "xcode",
        "version": 1
    ]
]

let data = try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys])
try data.write(to: output.appendingPathComponent("Contents.json"))
