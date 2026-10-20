import AppKit

/// 功率曲线：面积 + 折线 + 网格
final class LineChartView: NSView {
    var values: [Double] = []
    var labels: [String] = []
    /// 固定刻度：(横向位置 0…1, 文本)。时间轴用它，避免"每个点一个标签"再拍脑袋算小时。
    var ticks: [(CGFloat, String)] = []
    var color: NSColor = D.green
    var unit = "W"
    private var minMax: (Double, Double) = (0, 10)

    override var isFlipped: Bool { false }

    func set(_ v: [Double], labels: [String] = []) {
        values = v
        self.labels = labels
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds.insetBy(dx: 0, dy: 4)
        guard b.width > 10, b.height > 10 else { return }

        // 网格
        D.cardLine.setFill()
        for i in 0...3 {
            let y = b.minY + b.height * CGFloat(i) / 3
            NSRect(x: b.minX, y: y, width: b.width, height: 0.5).fill()
        }

        guard values.count > 1 else {
            let t = S.noRecord.v(Settings.shared.lang)
            let f = D.text(10)
            let s = t.size(f)
            t.draw(at: NSPoint(x: b.midX - s.width / 2, y: b.midY - s.height / 2),
                   withAttributes: [.font: f, .foregroundColor: D.tertiary])
            return
        }

        let mx = max(values.max() ?? 1, 1) * 1.15
        minMax = (0, mx)

        func pt(_ i: Int) -> NSPoint {
            let x = b.minX + b.width * CGFloat(i) / CGFloat(values.count - 1)
            let y = b.minY + b.height * CGFloat(min(values[i] / mx, 1))
            return NSPoint(x: x, y: y)
        }

        // 面积
        let area = NSBezierPath()
        area.move(to: NSPoint(x: b.minX, y: b.minY))
        for i in values.indices { area.line(to: pt(i)) }
        area.line(to: NSPoint(x: b.maxX, y: b.minY))
        area.close()
        NSGradient(colors: [color.withAlphaComponent(0.28), color.withAlphaComponent(0.02)])?.draw(in: area, angle: -90)

        // 线
        let line = NSBezierPath()
        line.move(to: pt(0))
        for i in values.indices.dropFirst() { line.line(to: pt(i)) }
        color.setStroke()
        line.lineWidth = 1.5
        line.lineJoinStyle = .round
        line.stroke()

        // 峰值标注
        if let peak = values.max() {
            let s = "\(String(format: "%.0f", peak))\(unit)"
            let f = D.num(9, .medium)
            let sz = s.size(f)
            s.draw(at: NSPoint(x: b.maxX - sz.width, y: b.maxY - sz.height),
                   withAttributes: [.font: f, .foregroundColor: D.tertiary])
        }

        // 固定刻度优先（时间轴走这条）
        if !ticks.isEmpty {
            let f = D.text(8)
            for (frac, l) in ticks {
                let sz = l.size(f)
                var x = b.minX + b.width * frac - sz.width / 2
                x = min(max(x, b.minX), b.maxX - sz.width)
                l.draw(at: NSPoint(x: x, y: b.minY + 1),
                       withAttributes: [.font: f, .foregroundColor: D.tertiary])
            }
        }

        // 时间轴
        if ticks.isEmpty, labels.count > 1 {
            let f = D.text(8)
            for (i, l) in labels.enumerated() where i % max(labels.count / 3, 1) == 0 {
                let x = b.minX + b.width * CGFloat(i) / CGFloat(labels.count - 1)
                let sz = l.size(f)
                l.draw(at: NSPoint(x: min(max(x - sz.width / 2, b.minX), b.maxX - sz.width), y: b.minY + 1),
                       withAttributes: [.font: f, .foregroundColor: D.tertiary])
            }
        }
    }
}

/// 近 7 天柱状图
final class BarChartView: NSView {
    var values: [Double] = []
    var labels: [String] = []
    /// 固定刻度：(横向位置 0…1, 文本)。时间轴用它，避免"每个点一个标签"再拍脑袋算小时。
    var ticks: [(CGFloat, String)] = []
    var color: NSColor = D.blue

    override var isFlipped: Bool { false }

    func set(_ v: [Double], labels: [String]) {
        values = v
        self.labels = labels
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let b = bounds
        guard b.width > 10, b.height > 20 else { return }
        let labelH: CGFloat = 14
        let chart = NSRect(x: b.minX, y: b.minY + labelH, width: b.width, height: b.height - labelH)
        if values.allSatisfy({ $0 <= 0.001 }) {
            let t = S.noRecord.v(Settings.shared.lang)
            let f = D.text(10)
            let sz = t.size(f)
            t.draw(at: NSPoint(x: b.midX - sz.width / 2, y: b.midY - sz.height / 2 + 2),
                   withAttributes: [.font: f, .foregroundColor: D.secondary])
            // 仍然画出日期标签，让"空"也有结构
            let n0 = max(values.count, 1)
            let slot0 = b.width / CGFloat(n0)
            for (i, l) in labels.enumerated() {
                let f2 = D.text(8)
                let s2 = l.size(f2)
                l.draw(at: NSPoint(x: b.minX + slot0 * CGFloat(i) + (slot0 - s2.width) / 2, y: b.minY + 1),
                       withAttributes: [.font: f2, .foregroundColor: D.secondary])
            }
            return
        }
        let mx = max(values.max() ?? 0, 1)
        let n = max(values.count, 1)
        let slot = chart.width / CGFloat(n)
        let barW = min(slot * 0.52, 22)

        D.cardLine.setFill()
        NSRect(x: b.minX, y: chart.minY, width: b.width, height: 0.5).fill()

        for (i, v) in values.enumerated() {
            let h = chart.height * CGFloat(min(v / mx, 1))
            let x = chart.minX + slot * CGFloat(i) + (slot - barW) / 2
            let r = NSRect(x: x, y: chart.minY, width: barW, height: max(h, v > 0 ? 2 : 0))
            color.withAlphaComponent(v > 0 ? 0.72 : 0).setFill()
            NSBezierPath(roundedRect: r, xRadius: 3, yRadius: 3).fill()

            if v > 0 {
                let s = String(format: "%.0f", v)
                let f = D.num(8, .medium)
                let sz = s.size(f)
                s.draw(at: NSPoint(x: r.midX - sz.width / 2, y: r.maxY + 1.5),
                       withAttributes: [.font: f, .foregroundColor: D.secondary])
            }
            if i < labels.count {
                let f = D.text(8)
                let sz = labels[i].size(f)
                labels[i].draw(at: NSPoint(x: r.midX - sz.width / 2, y: b.minY + 1),
                               withAttributes: [.font: f, .foregroundColor: D.tertiary])
            }
        }
    }
}

/// 水平进度条
final class LevelBar: NSView {
    var ratio: CGFloat = 0 { didSet { needsDisplay = true } }
    var color: NSColor = D.blue { didSet { needsDisplay = true } }
    var height: CGFloat = 5
    override var intrinsicContentSize: NSSize { NSSize(width: NSView.noIntrinsicMetric, height: height) }
    override var isFlipped: Bool { true }

    override func draw(_ dirtyRect: NSRect) {
        let h = height
        let y = (bounds.height - h) / 2
        D.trackFill.setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: y, width: bounds.width, height: h),
                     xRadius: h / 2, yRadius: h / 2).fill()
        let w = bounds.width * min(max(ratio, 0), 1)
        guard w > 1 else { return }
        color.setFill()
        NSBezierPath(roundedRect: NSRect(x: 0, y: y, width: w, height: h),
                     xRadius: h / 2, yRadius: h / 2).fill()
    }
}
