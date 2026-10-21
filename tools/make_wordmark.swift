// 生成 README 标题字标：浅色 / 深色两份 2x PNG（transparent 背景）
// GitHub 的 h1 自带下边框，会卡在标题和口号之间；用图片替代，顺便能自适应深浅色
import AppKit

let root = URL(fileURLWithPath: CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : ".")
let outDir = root.appendingPathComponent("docs/img")

func render(_ text: String, color: NSColor, path: URL) {
    let font = NSFont.systemFont(ofSize: 36, weight: .bold)
    let attr: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color,
        .kern: -0.6,
    ]
    let size = (text as NSString).size(withAttributes: attr)
    let scale: CGFloat = 2
    let px = NSSize(width: ceil(size.width) + 8, height: ceil(size.height))
    let img = NSImage(size: px)
    img.lockFocus()
    let ctx = NSGraphicsContext.current!
    ctx.shouldAntialias = true
    (text as NSString).draw(at: NSPoint(x: 4, y: 0), withAttributes: attr)
    img.unlockFocus()

    guard let tiff = img.tiffRepresentation, let rep = NSBitmapImageRep(data: tiff) else { return }
    rep.size = px
    // 放大到 2x 再用
    let big = NSBitmapImageRep(bitmapDataPlanes: nil,
                              pixelsWide: Int(px.width * scale),
                              pixelsHigh: Int(px.height * scale),
                              bitsPerSample: 8, samplesPerPixel: 4,
                              hasAlpha: true, isPlanar: false,
                              colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: big)
    NSGraphicsContext.current?.imageInterpolation = .high
    img.draw(in: NSRect(x: 0, y: 0, width: px.width * scale, height: px.height * scale))
    NSGraphicsContext.restoreGraphicsState()
    try? big.representation(using: .png, properties: [:])!.write(to: path)
    print("wrote \(path.lastPathComponent) \(big.pixelsWide)x\(big.pixelsHigh) 显示 \(Int(big.pixelsWide / 2))x\(Int(big.pixelsHigh / 2))")
}

render("PowerPulse", color: NSColor(srgbRed: 0.12, green: 0.14, blue: 0.16, alpha: 1),
       path: outDir.appendingPathComponent("wordmark-light.png"))
render("PowerPulse", color: NSColor(srgbRed: 0.90, green: 0.93, blue: 0.95, alpha: 1),
       path: outDir.appendingPathComponent("wordmark-dark.png"))
