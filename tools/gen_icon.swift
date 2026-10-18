import AppKit
import Foundation

// 生成 app 图标（不依赖设计工具）：深蓝渐变底 + 电池 + 闪电
let sizes = [16, 32, 64, 128, 256, 512, 1024]
let outDir = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "assets/AppIcon.iconset"
try? FileManager.default.createDirectory(atPath: outDir, withIntermediateDirectories: true)

func drawIcon(_ px: Int) -> Data? {
    guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px,
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                     isPlanar: false, colorSpaceName: .deviceRGB,
                                     bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let s = CGFloat(px)
    let ctx = NSGraphicsContext.current!.cgContext

    // 圆角方形底
    let radius = s * 0.2237
    let rect = CGRect(x: 0, y: 0, width: s, height: s)
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    ctx.addPath(path); ctx.clip()

    // 渐变：上深蓝下更深
    let colors = [NSColor(srgbRed: 0.13, green: 0.36, blue: 0.66, alpha: 1).cgColor,
                  NSColor(srgbRed: 0.05, green: 0.13, blue: 0.28, alpha: 1).cgColor] as CFArray
    if let g = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 1]) {
        ctx.drawLinearGradient(g, start: CGPoint(x: 0, y: s), end: CGPoint(x: 0, y: 0), options: [])
    }

    // 电池外形
    let tipW = s * 0.05
    let gap = s * 0.026
    let bw = s * 0.52, bh = s * 0.27
    let totalW = bw + gap + tipW
    let bx = (s - totalW) / 2
    let by = (s - bh) / 2
    let body = CGRect(x: bx, y: by, width: bw, height: bh)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: bh * 0.26, cornerHeight: bh * 0.26, transform: nil)
    ctx.setStrokeColor(NSColor.white.withAlphaComponent(0.92).cgColor)
    ctx.setLineWidth(s * 0.032)
    ctx.addPath(bodyPath); ctx.strokePath()

    // 正极
    let tip = CGRect(x: body.maxX + gap, y: by + bh * 0.30, width: tipW, height: bh * 0.40)
    ctx.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor)
    ctx.addPath(CGPath(roundedRect: tip, cornerWidth: s * 0.012, cornerHeight: s * 0.012, transform: nil))
    ctx.fillPath()

    // 电量填充
    let inset = s * 0.040
    let fillW = (bw - inset * 2) * 0.82
    let fill = CGRect(x: bx + inset, y: by + inset, width: fillW, height: bh - inset * 2)
    ctx.setFillColor(NSColor(srgbRed: 0.19, green: 0.82, blue: 0.42, alpha: 1).cgColor)
    ctx.addPath(CGPath(roundedRect: fill, cornerWidth: bh * 0.16, cornerHeight: bh * 0.16, transform: nil))
    ctx.fillPath()

    // 闪电
    ctx.setFillColor(NSColor.white.cgColor)
    let b = CGMutablePath()
    let cx = body.midX, cy = s * 0.5, hh = s * 0.095, ww = s * 0.045
    b.move(to: CGPoint(x: cx + ww * 0.2, y: cy + hh))
    b.addLine(to: CGPoint(x: cx - ww, y: cy - hh * 0.1))
    b.addLine(to: CGPoint(x: cx - ww * 0.1, y: cy - hh * 0.1))
    b.addLine(to: CGPoint(x: cx - ww * 0.3, y: cy - hh))
    b.addLine(to: CGPoint(x: cx + ww, y: cy + hh * 0.15))
    b.addLine(to: CGPoint(x: cx + ww * 0.1, y: cy + hh * 0.15))
    b.closeSubpath()
    ctx.addPath(b); ctx.fillPath()

    NSGraphicsContext.restoreGraphicsState()
    return rep.representation(using: .png, properties: [:])
}

var written = 0
for s in sizes {
    if let d = drawIcon(s) {
        let name = s == 1024 ? "icon_512x512@2x.png" : "icon_\(s)x\(s).png"
        try? d.write(to: URL(fileURLWithPath: "\(outDir)/\(name)"))
        written += 1
        // 附带 @2x 版本
        if s >= 16 && s < 1024 {
            try? d.write(to: URL(fileURLWithPath: "\(outDir)/icon_\(s / 2)x\(s / 2)@2x.png"))
        }
    }
}
print("wrote \(written) sizes to \(outDir)")
