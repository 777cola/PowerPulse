import AppKit

/// 功率流动画视图。
/// 三个节点串一条带：左节点(源) — 带 — 右节点(目标)。
///
/// 性能结构（重要）：静态部分（节点卡片、带子渐变、胶囊、文字、箭头）只在数据或尺寸变化时
/// 渲染进一张缓存的 NSImage；每帧只重画会动的点阵和扫光。否则 30fps 下每秒要重排 30 次文字、
/// 重建 30 次 SF Symbol 位图，主线程会被吃满、动画看起来就是"卡"。
final class FlowView: NSView {
    var snapshot = PowerSnapshot()
    var adapter: AdapterInfo?

    private var phase: CGFloat = 0
    private var timer: Timer?
    private var lastTick: CFTimeInterval = 0

    private var bodyImage: NSImage?
    private var bodyKey: String = ""
    private var renderingCache = false

    private let nodeW: CGFloat = 46
    private let gap: CGFloat = 9          // 节点与带之间的缝隙
    private let minBand: CGFloat = 22     // 带子最低高度，保证胶囊放得下
    private let maxBand: CGFloat = 56
    private let bandGap: CGFloat = 12     // 两条带之间的间距

    /// 一帧要动的带子
    private struct Band {
        let centerY: CGFloat
        let height: CGFloat
        let color: NSColor
        let moving: Bool        // 未充电的空态带不画点
        let sweep: Bool
    }
    private var bands: [Band] = []

    override var isFlipped: Bool { true }
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: 160) }

    /// 台式机：没有电池，没有墙插 / 电池功率，只说明现状
    private func drawNoBatteryBody() {
        let lang = Settings.shared.lang
        let title = S.noBattery.v(lang)
        let sub = S.mainsOnly.v(lang)

        let f1 = D.text(13, .medium)
        let f2 = D.text(10)
        let s1 = title.size(f1)
        let s2 = sub.size(f2)
        let gap: CGFloat = 6
        let total = s1.height + gap + s2.height
        let top = (bounds.height - total) / 2

        if let img = Icon.tinted("desktopcomputer", color: D.tertiary, size: 30) {
            img.draw(in: NSRect(x: (bounds.midX - 15).rounded(), y: top - 36, width: 30, height: 30))
        }
        title.draw(at: NSPoint(x: (bounds.midX - s1.width / 2).rounded(), y: top.rounded()),
                   withAttributes: [.font: f1, .foregroundColor: D.secondary])
        sub.draw(at: NSPoint(x: (bounds.midX - s2.width / 2).rounded(), y: (top + s1.height + gap).rounded()),
                 withAttributes: [.font: f2, .foregroundColor: D.tertiary])
    }

    // MARK: - 动画

    func startAnimating() {
        guard timer == nil else { return }
        lastTick = CACurrentMediaTime()
        let t = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in self?.tick() }
        // .common：窗口拖动、菜单跟踪时默认 mode 会被停掉，动画就"卡住一下"
        RunLoop.main.add(t, forMode: .common)
        timer = t
    }

    func stopAnimating() {
        timer?.invalidate()
        timer = nil
    }

    private func tick() {
        guard window != nil, !isHiddenOrHasHiddenAncestor else { return }
        let now = CACurrentMediaTime()
        // 按真实时间推进：主线程被采样/刷新占用时掉帧，但速度不变（不会忽快忽慢）
        let dt = min(now - lastTick, 0.25)
        lastTick = now
        let w = max(snapshot.isPluggedIn ? snapshot.wallW : snapshot.batteryW, 1)
        let speed = min(max(0.35 + w / 120.0, 0.35), 1.6)
        phase = (phase + CGFloat(speed * dt * 0.30)).truncatingRemainder(dividingBy: 1)
        needsDisplay = true
    }

    func update(_ s: PowerSnapshot, _ a: AdapterInfo?) {
        let changed = s.isPluggedIn != snapshot.isPluggedIn
            || s.isCharging != snapshot.isCharging
            || s.wallW != snapshot.wallW
            || s.systemUsageW != snapshot.systemUsageW
            || s.batteryChargeW != snapshot.batteryChargeW
            || s.batteryW != snapshot.batteryW
            || s.percent != snapshot.percent
            || s.timeToFull != snapshot.timeToFull
            || s.timeToEmpty != snapshot.timeToEmpty
            || a?.negotiatedW != adapter?.negotiatedW
        snapshot = s
        adapter = a
        if changed { invalidateBody() }
    }

    private func invalidateBody() {
        bodyImage = nil
        needsDisplay = true
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        invalidateBody()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        invalidateBody()
    }

    // MARK: - 绘制

    override func draw(_ dirtyRect: NSRect) {
        guard bounds.width > 120, bounds.height > 40 else { return }
        if !snapshot.hasBattery {
            drawNoBatteryBody()
            return
        }
        computeGeometry()
        if renderingCache {           // 正在抓缓存：只画静态层
            if snapshot.isPluggedIn { drawPluggedBody() } else { drawBatteryOnlyBody() }
            return
        }

        let key = bodySignature()
        if bodyImage == nil || key != bodyKey {
            bodyImage = renderBody()
            bodyKey = key
        }
        // 位图贴回时不能做插值：视图高度常常是 132.5 这种半像素，
        // 一重采样，胶囊里 13pt 的 8 就会糊成 3（真发生过）。
        NSGraphicsContext.current?.imageInterpolation = .none
        bodyImage?.draw(in: bounds.integral, from: .zero, operation: .sourceOver, fraction: 1,
                        respectFlipped: true, hints: nil)

        drawMotion()
    }

    /// 数据签名：任何影响静态画面的值变了才重渲染
    private func bodySignature() -> String {
        let dark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        return "\(dark)|\(Int(bounds.width))x\(Int(bounds.height))|\(snapshot.isPluggedIn)|\(snapshot.isCharging)"
            + "|\(snapshot.wallW)|\(snapshot.systemUsageW)|\(snapshot.batteryChargeW)|\(snapshot.batteryW)"
            + "|\(snapshot.percent)|\(snapshot.timeToFull)|\(snapshot.timeToEmpty)|\(Settings.shared.lang.rawValue)"
    }

    /// 把静态层抓成位图。用 NSView.cacheDisplay 而不是手算 CTM：
    /// 方向和 backing scale 都由 AppKit 处理，避免"文字倒过来/整体镜像"这类翻转错误。
    private func renderBody() -> NSImage {
        let img = NSImage(size: bounds.size)
        guard let rep = bitmapImageRepForCachingDisplay(in: bounds) else { return img }
        renderingCache = true
        cacheDisplay(in: bounds, to: rep)
        renderingCache = false
        img.addRepresentation(rep)
        return img
    }

    private func bandHeight(_ watts: Double) -> CGFloat {
        // 用 0.7 次方做压缩：12W 和 32W 在视觉上要能看出粗细差别，
        // 线性映射会被最小高度吃掉差量（两档只差 6pt）。
        let t = CGFloat(pow(min(max(watts / 60.0, 0), 1), 0.7))
        return minBand + (maxBand - minBand) * t
    }

    private var startX: CGFloat { nodeW + gap }
    private var endX: CGFloat { bounds.width - nodeW - gap }
    private var bandW: CGFloat { max(endX - startX, 1) }

    private func computeGeometry() {
        let h = bounds.height
        if snapshot.isPluggedIn {
            let sysW = max(snapshot.systemUsageW, 0.1)
            let chgW = max(snapshot.batteryChargeW, 0.1)
            let sysH = bandHeight(sysW)
            let chgH = bandHeight(chgW)
            let blockH = sysH + bandGap + chgH
            let top = (h - blockH) / 2
            let sysY = top + sysH / 2
            let batY = top + sysH + bandGap + chgH / 2
            let charging = snapshot.isCharging && chgW > 0.3
            bands = [
                Band(centerY: sysY, height: sysH, color: D.blue, moving: true, sweep: true),
                Band(centerY: batY, height: charging ? chgH : 6, color: charging ? D.green : D.tertiary,
                     moving: charging, sweep: charging),
            ]
        } else {
            let bh = bandHeight(max(snapshot.batteryW, 0.1))
            bands = [Band(centerY: h / 2, height: bh, color: D.orange, moving: true, sweep: true)]
        }
    }

    // MARK: 静态层

    private func drawPluggedBody() {
        let h = bounds.height
        let sysW = max(snapshot.systemUsageW, 0.1)
        let chgW = max(snapshot.batteryChargeW, 0.1)
        let charging = snapshot.isCharging && chgW > 0.3
        let sysY = bands[0].centerY
        let batY = bands[1].centerY
        let blockH = bands[0].height + bandGap + bands[1].height
        let top = (h - blockH) / 2

        for b in bands { drawBandBody(b) }

        drawNode(x: 0, centerY: h / 2, height: max(blockH, 46),
                 symbol: "powerplug.fill", value: String(format: "%.1f W", snapshot.wallW), color: D.label)
        drawNode(x: bounds.width - nodeW, centerY: sysY, height: max(bands[0].height, 46),
                 symbol: "desktopcomputer", value: S.system.v(Settings.shared.lang), color: D.blue)
        if charging {
            drawNode(x: bounds.width - nodeW, centerY: batY, height: max(bands[1].height, 46),
                     symbol: "battery.100.bolt", value: S.charge.v(Settings.shared.lang), color: D.green)
            drawCapsule("\(String(format: "%.1f", chgW)) W", centerY: batY, bandHeight: bands[1].height, color: D.green)
        } else {
            drawNode(x: bounds.width - nodeW, centerY: batY, height: 46,
                     symbol: "battery.100", value: S.idle.v(Settings.shared.lang), color: D.tertiary)
        }
        drawCapsule("\(String(format: "%.1f", sysW)) W", centerY: sysY, bandHeight: bands[0].height, color: D.blue)

        let tail: String
        if charging && snapshot.percent < 100 && snapshot.timeToFull > 0 {
            tail = "\(S.toFull.v(Settings.shared.lang)) \(fmtClock(snapshot.timeToFull))"
        } else if charging && snapshot.percent >= 100 {
            // 已经 100% 了还写"预计充满 44 分钟"就是自相矛盾
            tail = S.full.v(Settings.shared.lang)
        } else if snapshot.percent >= 99 {
            tail = S.full.v(Settings.shared.lang)
        } else {
            tail = "\(S.remaining.v(Settings.shared.lang)) \(fmtClock(snapshot.timeToEmpty))"
        }
        drawCaption(below: top + blockH + 8, text: tail)
    }

    private func drawBatteryOnlyBody() {
        let b = bands[0]
        drawBandBody(b)
        drawNode(x: 0, centerY: b.centerY, height: max(b.height, 46),
                 symbol: "battery.75", value: String(format: "%.1f W", max(snapshot.batteryW, 0.1)), color: D.orange)
        drawNode(x: bounds.width - nodeW, centerY: b.centerY, height: max(b.height, 46),
                 symbol: "desktopcomputer", value: S.system.v(Settings.shared.lang), color: D.orange)
        drawCapsule("\(String(format: "%.1f", max(snapshot.batteryW, 0.1))) W",
                    centerY: b.centerY, bandHeight: b.height, color: D.orange)
        drawCaption(below: b.centerY + b.height / 2 + 7,
                    text: "\(S.remaining.v(Settings.shared.lang)) \(fmtClock(snapshot.timeToEmpty))")
    }

    private func bandRect(_ b: Band) -> NSRect {
        NSRect(x: startX, y: b.centerY - b.height / 2, width: bandW, height: b.height)
    }

    /// 带子本体：渐变 + 描边 + 方向箭头（静态）
    private func drawBandBody(_ b: Band) {
        let rect = bandRect(b)
        let path = NSBezierPath(roundedRect: rect, xRadius: b.height / 2, yRadius: b.height / 2)
        let isDark = effectiveAppearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
        let a1: CGFloat = isDark ? 0.20 : 0.16
        let a2: CGFloat = isDark ? 0.46 : 0.38
        NSGradient(colors: [b.color.withAlphaComponent(a1),
                            b.color.withAlphaComponent(a2),
                            b.color.withAlphaComponent(a1)])?.draw(in: path, angle: 0)
        b.color.withAlphaComponent(isDark ? 0.30 : 0.42).setStroke()
        path.lineWidth = 0.5
        path.stroke()

        guard b.height > 12 else { return }
        let arrowH = min(b.height * 0.42, 12)
        let ax = endX - 9
        let arrow = NSBezierPath()
        arrow.move(to: NSPoint(x: ax - 4, y: b.centerY - arrowH / 2))
        arrow.line(to: NSPoint(x: ax + 3, y: b.centerY))
        arrow.line(to: NSPoint(x: ax - 4, y: b.centerY + arrowH / 2))
        arrow.lineWidth = 1.6
        arrow.lineCapStyle = .round
        arrow.lineJoinStyle = .round
        b.color.withAlphaComponent(0.85).setStroke()
        arrow.stroke()
    }

    /// 动画层：只有点和扫光，每帧重画
    private func drawMotion() {
        for b in bands {
            guard b.height > 12 else { continue }
            let rect = bandRect(b)

            if b.moving {
                let n = 6
                let d: CGFloat = 3.2
                for i in 0..<n {
                    let t = (CGFloat(i) / CGFloat(n) + phase).truncatingRemainder(dividingBy: 1)
                    let x = startX + 14 + (bandW - 28) * t
                    let alpha = sin(t * .pi) * 0.65 + 0.25
                    b.color.withAlphaComponent(alpha).setFill()
                    NSBezierPath(ovalIn: NSRect(x: x - d / 2, y: b.centerY - d / 2, width: d, height: d)).fill()
                }
            }

            guard b.sweep else { continue }
            NSGraphicsContext.saveGraphicsState()
            NSBezierPath(roundedRect: rect, xRadius: b.height / 2, yRadius: b.height / 2).addClip()
            let hx = startX + bandW * phase
            NSGradient(colors: [b.color.withAlphaComponent(0),
                                b.color.withAlphaComponent(0.14),
                                b.color.withAlphaComponent(0)])?
                .draw(in: NSRect(x: hx - bandW * 0.14, y: rect.minY,
                                 width: bandW * 0.28, height: b.height), angle: 0)
            NSGraphicsContext.restoreGraphicsState()
        }
    }

    /// 带子下方的一行小字（预计时间），顺便把竖向留白填掉
    private func drawCaption(below y: CGFloat, text: String) {
        let font = D.text(10)
        let size = text.size(font)
        // 视图比内容矮时贴底画，而不是整行丢掉
        let yy = min(y, bounds.height - size.height - 1)
        guard yy >= 0 else { return }
        text.draw(at: NSPoint(x: (bounds.midX - size.width / 2).rounded(), y: yy.rounded()),
                  withAttributes: [.font: font, .foregroundColor: D.secondary])
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
        let np = NSPoint(x: (rect.midX - textSize.width / 2).rounded(), y: (top + iconSize.height + 3).rounded())
        value.draw(at: np, withAttributes: [.font: font, .foregroundColor: D.secondary])
    }

    /// 数字胶囊：高度跟着带子走但永远留 5pt 余量，保证"嵌在带子里"
    private func drawCapsule(_ text: String, centerY: CGFloat, bandHeight: CGFloat, color: NSColor) {
        let font = D.text(13, .semibold)
        let size = text.size(font)
        let capH = min(size.height + 8, bandHeight - 3)
        let capW = size.width + 20
        let rect = NSRect(x: (startX + endX) / 2 - capW / 2, y: centerY - capH / 2, width: capW, height: capH)
        color.withAlphaComponent(0.95).setFill()
        let capPath = NSBezierPath(roundedRect: rect, xRadius: capH / 2, yRadius: capH / 2)
        capPath.fill()
        NSColor.white.withAlphaComponent(0.18).setStroke()
        capPath.lineWidth = 0.5
        capPath.stroke()
        let tp = NSPoint(x: (rect.midX - size.width / 2).rounded(),
                         y: (rect.midY - size.height / 2).rounded())
        text.draw(at: tp, withAttributes: [.font: font, .foregroundColor: NSColor.white])
    }
}
