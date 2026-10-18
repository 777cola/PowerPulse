import AppKit

// MARK: - 文本差异赋值

extension NSTextField {
    /// NSTextField.stringValue 即使赋相同值也会触发重新布局/重绘，
    /// 弹窗是玻璃材质，每触发一次就要重新合成一层模糊——省掉这些空转。
    func setText(_ s: String) {
        if stringValue != s { stringValue = s }
    }
    func setAttributed(_ a: NSAttributedString) {
        if attributedStringValue != a { attributedStringValue = a }
    }
}

// MARK: - 布局小工具

func vstack(_ views: [NSView], spacing: CGFloat = 8,
            alignment: NSLayoutConstraint.Attribute = .leading) -> NSStackView {
    let s = NSStackView(views: views)
    s.orientation = .vertical
    s.alignment = alignment
    s.spacing = spacing
    s.translatesAutoresizingMaskIntoConstraints = false
    return s
}

func hstack(_ views: [NSView], spacing: CGFloat = 8,
            alignment: NSLayoutConstraint.Attribute = .centerY) -> NSStackView {
    let s = NSStackView(views: views)
    s.orientation = .horizontal
    s.alignment = alignment
    s.spacing = spacing
    s.translatesAutoresizingMaskIntoConstraints = false
    return s
}

func spacer() -> NSView {
    let v = NSView()
    v.translatesAutoresizingMaskIntoConstraints = false
    v.setContentHuggingPriority(.init(1), for: .horizontal)
    return v
}

// MARK: - 图标（SF Symbols 着色）

enum Icon {
    private static var cache = [String: NSImage]()

    static func tinted(_ symbol: String, color: NSColor, size: CGFloat, weight: NSFont.Weight = .regular) -> NSImage? {
        let key = "\(symbol)-\(size)-\(color.hashValue)"
        if let hit = cache[key] { return hit }
        let cfg = NSImage.SymbolConfiguration(pointSize: size, weight: weight.symbolWeight)
        guard let base = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)?
            .withSymbolConfiguration(cfg) else { return nil }
        let out = NSImage(size: base.size)
        out.lockFocus()
        color.set()
        base.draw(in: NSRect(origin: .zero, size: base.size))
        NSRect(origin: .zero, size: base.size).fill(using: .sourceAtop)
        out.unlockFocus()
        out.isTemplate = false
        cache[key] = out
        return out
    }
}

extension NSFont.Weight {
    var symbolWeight: NSFont.Weight { self }
}

final class IconView: NSImageView {
    init(_ symbol: String, size: CGFloat = 12, color: NSColor = D.secondary, weight: NSFont.Weight = .regular) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        image = Icon.tinted(symbol, color: color, size: size, weight: weight)
        imageScaling = .scaleNone
        setContentHuggingPriority(.required, for: .horizontal)
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 卡片

final class Card: NSView {
    init(insets: NSEdgeInsets = .init(top: 10, left: 11, bottom: 10, right: 11),
         content: NSView, radius: CGFloat = D.radius) {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.cornerRadius = radius
        layer?.backgroundColor = D.cardFill.cgColor
        layer?.borderWidth = 0.5
        layer?.borderColor = D.cardLine.cgColor
        addSubview(content)
        content.pin(to: self, insets: insets)
    }
    required init?(coder: NSCoder) { fatalError() }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        layer?.backgroundColor = D.cardFill.cgColor
        layer?.borderColor = D.cardLine.cgColor
    }
}

// MARK: - 指标卡

final class MetricCard: NSView {
    private let titleLabel = label("", font: D.text(8.5), color: D.secondary)
    private let valueLabel = label("", font: D.rounded(13.5), color: D.label)
    private var iconView: IconView?

    init(title: String, symbol: String, color: NSColor) {
        super.init(frame: .zero)
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        layer?.cornerRadius = D.radius
        layer?.backgroundColor = D.cardFill.cgColor

        let icon = IconView(symbol, size: 9, color: color)
        iconView = icon
        titleLabel.stringValue = title
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        titleLabel.setContentHuggingPriority(.defaultLow, for: .horizontal)
        titleLabel.lineBreakMode = .byTruncatingTail
        valueLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        valueLabel.lineBreakMode = .byTruncatingTail
        let head = hstack([icon, titleLabel], spacing: 3)
        head.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let stack = vstack([head, valueLabel], spacing: 3)
        stack.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        addSubview(stack)
        stack.pin(to: self, insets: .init(top: 9, left: 5, bottom: 9, right: 5))
    }
    required init?(coder: NSCoder) { fatalError() }

    /// 没数据时整张卡"熄灯"，别让灰色占位看起来像激活的模块
    func setDimmed(_ dim: Bool) {
        iconView?.alphaValue = dim ? 0.4 : 1
        titleLabel.alphaValue = dim ? 0.55 : 1
    }

    func update(title: String? = nil, value: String, valueColor: NSColor = D.label) {
        if let t = title { titleLabel.setText(t) }
        valueLabel.setText(value)
        valueLabel.textColor = valueColor
        valueLabel.font = D.rounded(13.5)
    }
}

// MARK: - 等宽卡片行（手动布局，四等分绝不跑偏）

final class CardRow: NSView {
    private let items: [NSView]
    private let spacing: CGFloat
    init(_ items: [NSView], spacing: CGFloat = 7, height: CGFloat) {
        self.items = items
        self.spacing = spacing
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        items.forEach { addSubview($0) }
        heightAnchor.constraint(equalToConstant: height).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
    override var isFlipped: Bool { true }
    override func layout() {
        super.layout()
        let n = CGFloat(max(items.count, 1))
        let w = (bounds.width - spacing * (n - 1)) / n
        for (i, v) in items.enumerated() {
            v.frame = NSRect(x: (w + spacing) * CGFloat(i), y: 0, width: w, height: bounds.height)
        }
    }
}

// MARK: - 二级标题

final class SectionTitle: NSView {
    private let l = label("", font: D.text(11, .medium), color: D.secondary)
    init(_ text: String, symbol: String? = nil) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        var views: [NSView] = []
        if let s = symbol { views.append(IconView(s, size: 10, color: D.tertiary)) }
        l.stringValue = text
        views.append(l)
        let st = hstack(views, spacing: 5)
        addSubview(st)
        st.pin(to: self)
    }
    required init?(coder: NSCoder) { fatalError() }
    func set(_ text: String) { l.stringValue = text }
}

// MARK: - 键值行

final class KVRow: NSView {
    private let k = label("", font: D.text(12), color: D.secondary)
    private let v = label("", font: D.num(12, .medium), color: D.label, align: .right)
    private let iconView: IconView?
    init(_ key: String, symbol: String? = nil, value: String = "") {
        iconView = symbol.map { IconView($0, size: 11, color: D.tertiary) }
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        k.stringValue = key
        v.stringValue = value
        var left: [NSView] = []
        if let iconView { left.append(iconView) }
        left.append(k)
        let st = hstack([hstack(left, spacing: 6), spacer(), v], spacing: 6)
        addSubview(st)
        st.pin(to: self)
        heightAnchor.constraint(equalToConstant: 19).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
    func setValue(_ s: String, color: NSColor = D.label) {
        v.setText(s)
        if v.textColor != color { v.textColor = color }
    }
    func setKey(_ s: String) { k.setText(s) }
    func setKeyColor(_ c: NSColor) { if k.textColor != c { k.textColor = c } }
}

// MARK: - 底部 Tab（纯绘制，避免嵌套约束）

final class TabBar: NSView {
    struct Item { let symbol: String; let title: Tri }
    private var items: [Item] = []
    private var iconCache: [String: NSImage] = [:]
    var onSelect: ((Int) -> Void)?
    private(set) var selected = 0

    init(items: [Item]) {
        self.items = items
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        wantsLayer = true
        heightAnchor.constraint(equalToConstant: 52).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isFlipped: Bool { true }

    private func icon(_ symbol: String, _ color: NSColor) -> NSImage? {
        let key = symbol + (color == D.blue ? "on" : "off")
        if let i = iconCache[key] { return i }
        let i = Icon.tinted(symbol, color: color, size: 15)
        iconCache[key] = i
        return i
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.labelColor.withAlphaComponent(0.03).setFill()
        bounds.fill()
        D.cardLine.setFill()
        NSRect(x: 0, y: 0, width: bounds.width, height: 0.5).fill()

        let n = CGFloat(max(items.count, 1))
        let w = bounds.width / n
        // 选中底
        let r = NSRect(x: w * CGFloat(selected) + 7, y: 5, width: w - 14, height: bounds.height - 10)
        D.blue.withAlphaComponent(0.10).setFill()
        NSBezierPath(roundedRect: r, xRadius: 7, yRadius: 7).fill()

        for (i, it) in items.enumerated() {
            let on = i == selected
            let color = on ? D.blue : D.secondary
            if let img = icon(it.symbol, color) {
                let sz = img.size
                img.draw(in: NSRect(x: w * CGFloat(i) + (w - sz.width) / 2, y: 8,
                                    width: sz.width, height: sz.height))
            }
            let text = it.title.v(Settings.shared.lang)
            let attrs: [NSAttributedString.Key: Any] = [.font: D.text(9), .foregroundColor: color]
            let size = text.size(D.text(9))
            text.draw(at: NSPoint(x: w * CGFloat(i) + (w - size.width) / 2, y: 30), withAttributes: attrs)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let p = convert(event.locationInWindow, from: nil)
        let n = CGFloat(max(items.count, 1))
        let idx = Int(p.x / (bounds.width / n))
        guard idx >= 0 && idx < items.count else { return }
        select(idx)
    }

    /// 只改外观，不触发回调（避免 show ↔ select 互相递归）
    func highlight(_ idx: Int) {
        guard idx >= 0 && idx < items.count else { return }
        selected = idx
        needsDisplay = true
    }

    func select(_ idx: Int) {
        highlight(idx)
        onSelect?(idx)
    }

    func relabel() { needsDisplay = true }
}

// MARK: - 分段控件样式的小按钮

final class PillButton: NSButton {
    init(_ title: String, target: AnyObject?, action: Selector) {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        self.title = title
        self.target = target
        self.action = action
        bezelStyle = .rounded
        font = D.text(11)
        controlSize = .small
    }
    required init?(coder: NSCoder) { fatalError() }
}

// MARK: - 开关行

final class SwitchRow: NSView {
    private let l: NSTextField
    let toggle = NSSwitch()
    var onChange: ((Bool) -> Void)?
    init(_ title: String, on: Bool) {
        l = label(title, font: D.text(12), color: D.label)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        toggle.state = on ? .on : .off
        toggle.controlSize = .mini
        toggle.target = self
        toggle.action = #selector(fired)
        let st = hstack([l, spacer(), toggle], spacing: 8)
        addSubview(st)
        st.pin(to: self)
        heightAnchor.constraint(equalToConstant: 24).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func fired() { onChange?(toggle.state == .on) }
    func setTitle(_ s: String) { l.stringValue = s }
    func setOn(_ b: Bool) { toggle.state = b ? .on : .off }
}

// MARK: - 下拉行

final class PopupRow: NSView {
    let popup = NSPopUpButton()
    private let l: NSTextField
    var onChange: ((Int) -> Void)?
    init(_ title: String, options: [String], selected: Int) {
        l = label(title, font: D.text(12), color: D.label)
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        popup.translatesAutoresizingMaskIntoConstraints = false
        popup.addItems(withTitles: options)
        popup.selectItem(at: min(max(selected, 0), options.count - 1))
        popup.controlSize = .small
        popup.font = D.text(11)
        popup.target = self
        popup.action = #selector(fired)
        let st = hstack([l, spacer(), popup], spacing: 8)
        addSubview(st)
        st.pin(to: self)
        heightAnchor.constraint(equalToConstant: 26).isActive = true
        popup.widthAnchor.constraint(greaterThanOrEqualToConstant: 108).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func fired() { onChange?(popup.indexOfSelectedItem) }
    func setTitle(_ s: String) { l.stringValue = s }
    func setOptions(_ o: [String], selected i: Int) {
        popup.removeAllItems()
        popup.addItems(withTitles: o)
        popup.selectItem(at: min(max(i, 0), o.count - 1))
    }
}
