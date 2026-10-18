import AppKit

/// 功率流动画视图。
/// 三个节点串一条带：左节点(源) — 带 — 右节点(目标)。
/// 节点是同尺寸圆角卡片，两端视觉重量对齐；带子有最小高度，胶囊数字永远嵌在带里不会溢出。
final class FlowView: NSView {
    var snapshot = PowerSnapshot()
    var adapter: AdapterInfo?
    private var phase: CGFloat = 0
    private var timer: Timer?

    private let nodeW: CGFloat = 46
    private let gap: CGFloat = 9          // 节点与带之间的缝隙
    private let minBand: CGFloat = 22     // 带子最低高度，保证胶囊放得下
    private let maxBand: CGFloat = 56
    private let bandGap: CGFloat = 12     // 两条带之间的间距

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 160) }

    // MARK: - 动画

    func startAnimating() {
        guard timer == nil else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10.0, repeats: true) { [weak self] _ in
            guard let self, self.window != nil else { return }
            let w = max(self.snapshot.isPluggedIn ? self.snapshot.wallW : self.snapshot.batteryW, 1)
            let speed = min(max(0.35 + w / 120.0, 0.35), 1.6)
            self.phase = (self.phase + CGFloat(speed) * 0.030).truncatingRemainder(dividingBy: 1)
            self.needsDisplay = true
        }
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }

    func update(_ s: PowerSnapshot, _ a: AdapterInfo?) {
        let stateChanged = s.isPluggedIn != snapshot.isPluggedIn || s.isCharging != snapshot.isCharging
        snapshot = s
        adapter = a
        if stateChanged { needsDisplay = true }
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 120, bounds.height > 40 else { return }
        if snapshot.isPluggedIn { drawPlugged() } else { drawBatteryOnly() }
    }

    private func bandHeight(_ watts: Double) -> CGFloat {
        // 用 0.7 次方做压缩：12W 和 32W 在视觉上要能看出粗细差别，
        // 线性映射会被最小高度吃掉差量（两档只差 6pt）。
        let t = CGFloat(pow(min(max(watts / 60.0, 0), 1), 0.7))
        return minBand + (maxBand - minBand) * t
    }

    private var startX: CGFloat { nodeW + gap }
    private var endX: CGFloat { bounds.width - nodeW - gap }

    // MARK: 插电：墙插 → 系统 / 电池

    private func drawPlugged() {
        let h = bounds.height
        let sysW = max(snapshot.systemUsageW, 0.1)
        let chgW = max(snapshot.batteryChargeW, 0.1)
        let sysH = bandHeight(sysW)
        let chgH = bandHeight(chgW)
        let blockH = sysH + bandGap + chgH
        let top = (h - blockH) / 2
        let sysY = top + sysH / 2
        let batY = top + sysH + bandGap + chgH / 2
        let charging = snapshot.isCharging && chgW > 0.3

        // 带子先画，节点卡片盖在两端
        drawBand(centerY: sysY, height: sysH, color: D.blue)
        if charging {
            drawBand(centerY: batY, height: chgH, color: D.green)
        } else {
            drawBand(centerY: batY, height: 6, color: D.tertiary, dots: false, sweep: false)
        }

        drawNode(x: 0, centerY: h / 2, height: max(blockH, 46),
                 symbol: "powerplug.fill", value: String(format: "%.1f W", snapshot.wallW), color: D.label)
        drawNode(x: bounds.width - nodeW, centerY: sysY, height: max(sysH, 46),
                 symbol: "desktopcomputer", value: S.system.v(Settings.shared.lang), color: D.blue)
        if charging {
            drawNode(x: bounds.width - nodeW, centerY: batY, height: max(chgH, 46),
                     symbol: "battery.100.bolt", value: S.charge.v(Settings.shared.lang), color: D.green)
            drawCapsule("\(String(format: "%.1f", chgW)) W", centerY: batY, bandHeight: chgH, color: D.green)
        } else {
            drawNode(x: bounds.width - nodeW, centerY: batY, height: 46,
                     symbol: "battery.100", value: S.idle.v(Settings.shared.lang), color: D.tertiary)
        }
        drawCapsule("\(String(format: "%.1f", sysW)) W", centerY: sysY, bandHeight: sysH, color: D.blue)

        let tail: String
        if charging {
            tail = "\(S.toFull.v(Settings.shared.lang)) \(fmtClock(snapshot.timeToFull))"
        } else if snapshot.percent >= 99 {
            tail = S.full.v(Settings.shared.lang)
        } else {
            tail = "\(S.remaining.v(Settings.shared.lang)) \(fmtClock(snapshot.timeToEmpty))"
        }
        drawCaption(below: top + blockH + 8, text: tail)
    }

    /// 带子下方的一行小字（预计时间），顺便把竖向留白填掉
    private func drawCaption(below y: CGFloat, text: String) {
        let font = D.text(10)
        let size = text.size(font)
        guard y + size.height < bounds.height else { return }
        text.draw(at: NSPoint(x: bounds.midX - size.width / 2, y: y),
                  withAttributes: [.font: font, .foregroundColor: D.secondary])
    }

    // MARK: 放电：电池 → 系统

    private func drawBatteryOnly() {
        let h = bounds.height
        let batW = max(snapshot.batteryW, 0.1)
        let bh = bandHeight(batW)
        let y = h / 2

        drawBand(centerY: y, height: bh, color: D.orange)
        drawNode(x: 0, centerY: y, height: max(bh, 46),
                 symbol: "battery.75", value: String(format: "%.1f W", batW), color: D.orange)
        drawNode(x: bounds.width - nodeW, centerY: y, height: max(bh, 46),
                 symbol: "desktopcomputer", value: S.system.v(Settings.shared.lang), color: D.orange)
        drawCapsule("\(String(format: "%.1f", batW)) W", centerY: y, bandHeight: bh, color: D.orange)
        drawCaption(below: y + bh / 2 + 7, text: "\(S.remaining.v(Settings.shared.lang)) \(fmtClock(snapshot.timeToEmpty))")
    }

    // MARK: - 元件

    private func drawBand(centerY: CGFloat, height: CGFloat, color: NSColor,
                          dots: Bool = true, sweep: Bool = true) {
        let rect = NSRect(x: startX, y: centerY - height / 2, width: max(endX - startX, 1), height: height)
        let path = NSBezierPath(roundedRect: rect, xRadius: height / 2, yRadius: height / 2)

        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let a1: CGFloat = isDark ? 0.20 : 0.16
        let a2: CGFloat = isDark ? 0.46 : 0.38
        NSGradient(colors: [color.withAlphaComponent(a1),
                            color.withAlphaComponent(a2),
                            color.withAlphaComponent(a1)])?.draw(in: path, angle: 0)
        color.withAlphaComponent(isDark ? 0.30 : 0.42).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        guard dots, height > 12 else { return }
        let n = 6
        for i in 0..<n {
            let t = (CGFloat(i) / CGFloat(n) + phase).truncatingRemainder(dividingBy: 1)
            let x = startX + 14 + (endX - startX - 28) * t
            let alpha = sin(t * .pi) * 0.65 + 0.25
            let d: CGFloat = 3.2
            color.withAlphaComponent(alpha).setFill()
            NSBezierPath(ovalIn: NSRect(x: x - d / 2, y: centerY - d / 2, width: d, height: d)).fill()
        }

        // 方向箭头：贴在带子右端内侧
        let arrowH = min(height * 0.42, 12)
        let ax = endX - 9
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: ax - 4, y: centerY - arrowH / 2))
        arrow.line(to: NSPoint(x: ax + 3, y: centerY))
        arrow.line(to: NSPoint(x: ax - 4, y: centerY + arrowH / 2))
        arrow.lineWidth = 1.6
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        color.withAlphaComponent(0.85).setStroke()
        arrow.stroke()

        guard sweep else { return }
        NSGraphicsContext.saveGraphicsState()
        path.addClip()
        let bandW = endX - startX
        let hx = startX + bandW * phase
        let hi = NSGradient(colors: [color.withAlphaComponent(0), color.withAlphaComponent(0.14), color.withAlphaComponent(0)])
        hi?.draw(in: NSRect(x: hx - bandW * 0.14, y: centerY - height / 2, width: bandW * 0.28, height: height), angle: 0)
        NSGraphicsContext.restoreGraphicsState()
    }

    /// 两端统一的节点卡片：图标在上、文字在下，整体垂直居中
    private func drawNode(x: CGFloat, centerY: CGFloat, height: CGFloat,
                          symbol: String, value: String, color: NSColor) {
        let rect = NSRect(x: x, y: centerY - height / 2, width: nodeW, height: height)
        D.cardFill.setFill()
        let path = NSBezierPath(roundedRect: rect, xRadius: 9, yRadius: 9)
        path.fill()
        D.cardLine.setStroke()
        path.lineWidth = 0.5
        path.stroke()

        let isWord = !value.contains("W")
        let font = isWord ? D.text(9) : D.rounded(11, .medium)
        let textSize = value.size(font)
        let iconSize = Icon.tinted(symbol, color: color, size: 14)?.size ?? .zero
        let stackH = iconSize.height + 3 + textSize.height
        let top = rect.midY - stackH / 2

        if let img = Icon.tinted(symbol, color: color, size: 14) {
            img.draw(in: NSRect(x: rect.midX - iconSize.width / 2, y: top,
                                width: iconSize.width, height: iconSize.height))
        }
        value.draw(at: NSPoint(x: rect.midX - textSize.width / 2, y: top + iconSize.height + 3),
                   withAttributes: [.font: font, .foregroundColor: D.secondary])
    }

    /// 数字胶囊：高度跟着带子走但永远留 5pt 余量，保证"嵌在带子里"
    private func drawCapsule(_ text: String, centerY: CGFloat, bandHeight: CGFloat, color: NSColor) {
        let font = D.rounded(11.5, .semibold)
        let size = text.size(font)
        let capH = min(size.height + 7, bandHeight - 4)
        let capW = size.width + 18
        let rect = NSRect(x: (startX + endX) / 2 - capW / 2, y: centerY - capH / 2, width: capW, height: capH)
        color.withAlphaComponent(0.95).setFill()
        let capPath = NSBezierPath(roundedRect: rect, xRadius: capH / 2, yRadius: capH / 2)
        capPath.fill()
        NSColor.white.withAlphaComponent(0.18).setStroke()
        capPath.lineWidth = 0.5
        capPath.stroke()
        text.draw(at: NSPoint(x: rect.midX - size.width / 2, y: rect.midY - size.height / 2),
                  withAttributes: [.font: font, .foregroundColor: NSColor.white])
    }
}
