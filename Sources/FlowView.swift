import AppKit

/// 功率流动画视图 —— 复刻现版设计：左侧源块，右侧系统/电池，中间流动带。
final class FlowView: NSView {
    var snapshot = PowerSnapshot()
    var adapter: AdapterInfo?
    private var phase: CGFloat = 0
    private var timer: Timer?

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 160) }

    func startAnimating() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            // 功率越大流得越快：1.5s(慢) ~ 0.7s(快) 一圈
            let w = max(self.snapshot.isPluggedIn ? self.snapshot.wallW : self.snapshot.batteryW, 1)
            let speed = min(max(0.35 + w / 120.0, 0.35), 1.6)
            self.phase = (self.phase + CGFloat(speed) * 0.022).truncatingRemainder(dividingBy: 1)
            self.needsDisplay = true
        }
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }

    func update(_ s: PowerSnapshot, _ a: AdapterInfo?) {
        snapshot = s
        adapter = a
        needsDisplay = true
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        let w = bounds.width
        let h = bounds.height
        guard w > 60, h > 20 else { return }

        if snapshot.isPluggedIn {
            drawPlugged(w: w, h: h)
        } else {
            drawBatteryOnly(w: w, h: h)
        }
    }

    private func drawPlugged(w: CGFloat, h: CGFloat) {
        let sysW = max(snapshot.systemUsageW, 0.1)
        let chgW = max(snapshot.batteryChargeW, 0.1)
        let total = max(snapshot.wallW, sysW + chgW, 1)
        let sysRatio = min(sysW / total, 1)
        let chgRatio = min(chgW / total, 1)

        let gap: CGFloat = 10
        let half = (h - gap) / 2
        let sysH = max(half * CGFloat(sysRatio), 18)
        let batH = max(half * CGFloat(chgRatio), 18)
        let sourceH = sysH + batH + gap
        let sysY = half / 2
        let batY = half + gap + half / 2
        let startX: CGFloat = 38
        let endX = w - 34

        // 先把两条带画出来，再把源块盖在上面 —— 视觉上能量是从块里流出去的
        // 系统流
        drawBand(startX: startX, endX: endX, centerY: sysY, height: sysH,
                 color: D.blue, cooling: false)
        drawCapsule("\(String(format: "%.1f", sysW)) W", center: NSPoint(x: (startX + endX) / 2, y: sysY), color: D.blue)
        drawEndIcon(x: w - 17, y: sysY, symbol: "desktopcomputer", text: S.system.v(Settings.shared.lang), color: D.blue)

        // 电池流
        if snapshot.isCharging && chgW > 0.3 {
            drawBand(startX: startX, endX: endX, centerY: batY, height: batH,
                     color: D.green, cooling: false)
            drawCapsule("\(String(format: "%.1f", chgW)) W", center: NSPoint(x: (startX + endX) / 2, y: batY), color: D.green)
            drawEndIcon(x: w - 17, y: batY, symbol: "battery.100.bolt", text: S.charge.v(Settings.shared.lang), color: D.green)
        } else {
            // 插着电但不充电：一条淡淡的待机带
            drawBand(startX: startX, endX: endX, centerY: batY, height: 4,
                     color: D.tertiary, cooling: true, dots: false, sweep: false)
            drawEndIcon(x: w - 17, y: batY, symbol: "battery.100", text: S.idle.v(Settings.shared.lang), color: D.tertiary)
        }

        drawSourceBlock(x: 0, y: (h - sourceH) / 2, height: sourceH,
                        watts: snapshot.wallW, symbol: "powerplug.fill", color: D.label)
    }

    private func drawBatteryOnly(w: CGFloat, h: CGFloat) {
        let batW = max(snapshot.batteryW, 0.1)
        let centerY = h / 2
        let bandH = max(min(h * 0.6, h * 0.6 * CGFloat(batW / 45.0)), 12)
        let startX: CGFloat = 38
        let endX = w - 34

        drawBand(startX: startX, endX: endX, centerY: centerY, height: bandH,
                 color: D.orange, cooling: false)
        drawCapsule("\(String(format: "%.1f", batW)) W", center: NSPoint(x: (startX + endX) / 2, y: centerY), color: D.orange)
        drawEndIcon(x: w - 17, y: centerY, symbol: "desktopcomputer",
                    text: S.system.v(Settings.shared.lang), color: D.orange)
        drawSourceBlock(x: 0, y: (h - bandH) / 2, height: bandH,
                        watts: batW, symbol: "battery.100", color: D.orange)
    }

    // MARK: - 组件

    private func drawSourceBlock(x: CGFloat, y: CGFloat, height: CGFloat,
                                 watts: Double, symbol: String, color: NSColor) {
        let rect = NSRect(x: x, y: y, width: 46, height: max(height, 34))
        NSColor.labelColor.withAlphaComponent(0.07).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 8, yRadius: 8).fill()

        let text = "\(fmtW(watts)) W"
        let attrs: [NSAttributedString.Key: Any] = [.font: D.rounded(12), .foregroundColor: D.label]
        let size = text.size(D.rounded(12))
        let iconSize = Icon.tinted(symbol, color: color, size: 14)?.size ?? .zero
        let blockH = iconSize.height + 3 + size.height
        let top = rect.midY - blockH / 2
        if let img = Icon.tinted(symbol, color: color, size: 14) {
            img.draw(in: NSRect(x: rect.midX - iconSize.width / 2, y: top,
                                width: iconSize.width, height: iconSize.height))
        }
        text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: top + iconSize.height + 3), withAttributes: attrs)
    }

    private func bandPath(startX: CGFloat, endX: CGFloat, centerY: CGFloat, height: CGFloat) -> NSBezierPath {
        let half = height / 2
        let mid = (startX + endX) / 2
        let p = NSBezierPath()
        p.move(to: NSPoint(x: startX, y: centerY - half))
        p.curve(to: NSPoint(x: endX, y: centerY - half),
                controlPoint1: NSPoint(x: mid, y: centerY - half - 2),
                controlPoint2: NSPoint(x: mid, y: centerY - half - 2))
        p.curve(to: NSPoint(x: endX, y: centerY + half),
                controlPoint1: NSPoint(x: endX + 4, y: centerY),
                controlPoint2: NSPoint(x: endX + 4, y: centerY))
        p.curve(to: NSPoint(x: startX, y: centerY + half),
                controlPoint1: NSPoint(x: mid, y: centerY + half + 2),
                controlPoint2: NSPoint(x: mid, y: centerY + half + 2))
        p.curve(to: NSPoint(x: startX, y: centerY - half),
                controlPoint1: NSPoint(x: startX - 4, y: centerY),
                controlPoint2: NSPoint(x: startX - 4, y: centerY))
        p.close()
        return p
    }

    private func drawBand(startX: CGFloat, endX: CGFloat, centerY: CGFloat, height: CGFloat,
                          color: NSColor, cooling: Bool, dots: Bool = true, sweep: Bool = true) {
        let path = bandPath(startX: startX, endX: endX, centerY: centerY, height: height)

        // 主体渐变（不做每帧高斯模糊——那是 CPU 的大头）
        let grad = NSGradient(colors: [color.withAlphaComponent(0.12),
                                       color.withAlphaComponent(0.34),
                                       color.withAlphaComponent(0.12)])
        grad?.draw(in: path, angle: 0)
        color.withAlphaComponent(0.28).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        guard dots, height > 8 else { return }
        // 流动的粒子
        let n = 6
        for i in 0..<n {
            let t = (CGFloat(i) / CGFloat(n) + phase).truncatingRemainder(dividingBy: 1)
            let x = startX + (endX - startX) * t
            let wob = sin(t * .pi * 2) * 1.5
            let alpha = sin(t * .pi) * 0.65 + 0.1
            let size = 2.5 + sin(t * .pi) * 1.4
            let r = NSRect(x: x - size / 2, y: centerY + wob - size / 2, width: size, height: size)
            color.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: r).fill()
        }

        // 高光扫过
        guard sweep else { return }
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        let bandW = endX - startX
        let hx = startX + bandW * phase
        let rect = NSRect(x: hx - bandW * 0.15, y: centerY - height / 2, width: bandW * 0.3, height: height)
        let hi = NSGradient(colors: [color.withAlphaComponent(0), color.withAlphaComponent(0.16), color.withAlphaComponent(0)])
        hi?.draw(in: rect, angle: 0)
        NSGraphicsContext.restoreGraphicsState()
    }

    private func drawCapsule(_ text: String, center: NSPoint, color: NSColor) {
        let font = D.rounded(11)
        let size = text.size(font)
        let padX: CGFloat = 7, padY: CGFloat = 2.5
        let rect = NSRect(x: center.x - size.width / 2 - padX, y: center.y - size.height / 2 - padY,
                          width: size.width + padX * 2, height: size.height + padY * 2)
        color.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: rect, xRadius: rect.height / 2, yRadius: rect.height / 2).fill()
        text.draw(at: NSPoint(x: rect.minX + padX, y: rect.minY + padY - 0.5),
                  withAttributes: [.font: font, .foregroundColor: NSColor.white])
    }

    private func drawEndIcon(x: CGFloat, y: CGFloat, symbol: String, text: String, color: NSColor) {
        if let img = Icon.tinted(symbol, color: color, size: 16) {
            let sz = img.size
            img.draw(in: NSRect(x: x - sz.width / 2, y: y - sz.height / 2 - 5, width: sz.width, height: sz.height))
        }
        let font = D.text(9)
        let size = text.size(font)
        text.draw(at: NSPoint(x: x - size.width / 2, y: y + 9),
                  withAttributes: [.font: font, .foregroundColor: D.secondary])
    }
}
