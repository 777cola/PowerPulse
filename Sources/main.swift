import AppKit
import Foundation

// MARK: - 弹窗

final class PopoverController: NSObject {
    let popover = NSPopover()
    let container = NSView()
    private let headerTitle = label("", font: D.text(13, .medium), color: D.label)
    private var headerIcon = IconView("bolt.horizontal.fill", size: 12, color: D.secondary)
    private let langButton = NSButton()
    private(set) var panels: [Panel] = []
    private var tabBar: TabBar!
    private var current = 0
    let panelHost = NSView()
    private var hostHeight: NSLayoutConstraint!

    private var titles: [Tri] = [S.powerFlow, S.monitor, S.history, S.adapter, S.settings]
    private var symbols = ["bolt.horizontal", "cpu", "clock.arrow.circlepath", "powerplug", "gearshape"]

    var onSizeChange: ((NSSize) -> Void)?

    override init() {
        super.init()
        build()
    }

    private func build() {
        let root = NSView(frame: NSRect(x: 0, y: 0, width: D.width, height: 420))
        root.wantsLayer = true

        // 玻璃底
        let glass = NSVisualEffectView()
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.alphaValue = 0.55
        glass.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(glass)
        glass.pin(to: root)

        // 顶部标题栏
        let header = NSView()
        header.translatesAutoresizingMaskIntoConstraints = false
        header.heightAnchor.constraint(equalToConstant: 38).isActive = true
        headerTitle.translatesAutoresizingMaskIntoConstraints = false
        headerIcon.translatesAutoresizingMaskIntoConstraints = false

        langButton.isBordered = false
        langButton.translatesAutoresizingMaskIntoConstraints = false
        langButton.target = self
        langButton.action = #selector(cycleLang)
        langButton.font = D.text(10, .medium)
        langButton.contentTintColor = D.secondary
        langButton.wantsLayer = true
        langButton.layer?.cornerRadius = 5
        langButton.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        langButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
        langButton.heightAnchor.constraint(equalToConstant: 18).isActive = true
        refreshLangButton()

        let head = hstack([headerIcon, headerTitle, spacer(), langButton], spacing: 6)
        header.addSubview(head)
        head.pin(to: header, insets: .init(top: 0, left: D.pad, bottom: 0, right: D.pad))

        // 面板容器
        panelHost.translatesAutoresizingMaskIntoConstraints = false
        hostHeight = panelHost.heightAnchor.constraint(equalToConstant: 300)
        hostHeight.isActive = true

        // Tab
        tabBar = TabBar(items: zip(symbols, titles).map { TabBar.Item(symbol: $0.0, title: $0.1) })
        tabBar.onSelect = { [weak self] i in self?.show(i) }

        let stack = vstack([header, panelHost, tabBar], spacing: 0)
        root.addSubview(stack)
        stack.pin(to: root)
        header.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        panelHost.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        tabBar.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        container.addSubview(root)
        root.pin(to: container)

        panels = [NowPanel(), MonitorPanel(), HistoryPanel(), AdapterPanel(), SettingsPanel()]
        for p in panels {
            p.translatesAutoresizingMaskIntoConstraints = false
            p.wantsLayer = true
            p.layer?.masksToBounds = true
            panelHost.addSubview(p)
            p.pin(to: panelHost)
        }
        show(0)

        let vc = NSViewController()
        vc.view = container
        container.setFrameSize(NSSize(width: D.width, height: 420))
        popover.contentViewController = vc
        popover.behavior = .transient
        popover.animates = true
    }

    func select(_ idx: Int) { show(idx) }
    var panelCount: Int { panels.count }
    func panelsHeight(_ i: Int) -> CGFloat { 38 + panels[i].preferredHeight + 52 }

    private func show(_ idx: Int) {
        current = idx
        for (i, p) in panels.enumerated() { p.isHidden = i != idx }
        headerTitle.stringValue = titles[idx].v(Settings.shared.lang)
        headerIcon.image = Icon.tinted(symbols[idx], color: D.secondary, size: 12)
        tabBar.highlight(idx)

        let h = panels[idx].preferredHeight
        hostHeight.constant = h
        container.frame.size = NSSize(width: D.width, height: 38 + h + 52)
        popover.contentSize = container.frame.size
        onSizeChange?(container.frame.size)
    }

    @objc private func cycleLang() {
        Settings.shared.lang = Settings.shared.lang.next
        NotificationCenter.default.post(name: .ppSettingsChanged, object: nil)
    }

    func refreshLangButton() {
        langButton.title = Settings.shared.lang.short
        langButton.sizeToFit()
    }

    /// 语言切换后整体重建，避免残留旧文案
    func rebuild() {
        let idx = current
        container.subviews.forEach { $0.removeFromSuperview() }
        panels = []
        build()
        show(min(idx, panels.count - 1))
    }

    func refresh(power: PowerSnapshot, adapter: AdapterInfo?, stats: SystemStats, energy: [ProcessEnergy]) {
        guard let p = panels[safe: current] else { return }
        p.refresh(power: power, adapter: adapter, stats: stats, energy: energy)
    }
}

extension Array {
    subscript(safe i: Int) -> Element? { indices.contains(i) ? self[i] : nil }
}

// MARK: - App

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    // 必须 lazy：PopoverController 会建 NSVisualEffectView / NSPopover 层级，
    // 放在存储属性初始化器里会在 applicationDidFinishLaunching 之前跑，状态栏窗口高度会变成 0
    private lazy var popover = PopoverController()
    private var eventMonitor: Any?
    private var snapshot = PowerSnapshot()
    private var adapter: AdapterInfo?
    private var stats = SystemStats()
    private var energy: [ProcessEnergy] = []
    private var lastUI = Date.distantPast
    private let watcher = PowerSourceWatcher()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let skip = Set((CommandLine.arguments.first(where: { $0.hasPrefix("--skip=") })?
            .replacingOccurrences(of: "--skip=", with: "") ?? "").split(separator: ",").map(String.init))
        if !skip.contains("history") {
            HistoryStore.shared.open()
            HistoryStore.shared.prune(days: Settings.shared.retentionDays)
        }
        if !skip.contains("notifier") { Notifier.shared.setUp() }
        setupStatusItem()
        setupPopover()
        setupMenu()

        if !skip.contains("watcher") {
            watcher.onChange = { [weak self] in self?.pump(force: true) }
            watcher.start()
        }

        Sampler.shared.onSample = { [weak self] s, a in
            guard let self else { return }
            self.snapshot = s
            self.adapter = a
            self.onTick()
        }
        Sampler.shared.onSystem = { [weak self] st in self?.stats = st }
        Sampler.shared.onEnergy = { [weak self] e in self?.energy = e }
        if !skip.contains("sampler") { Sampler.shared.start(interval: Settings.shared.interval) }

        NotificationCenter.default.addObserver(forName: .ppSettingsChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
            self.popover.refreshLangButton()
            self.popover.rebuild()
            self.updateStatusTitle()
        }

        // 首次启动默认注册开机自启（失败就静默放弃）
        if !Settings.shared.onboarded, !skip.contains("loginitem") {
            Settings.shared.onboarded = true
            _ = LoginItem.set(true)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self] in self?.updateStatusTitle() }

        // 调试：启动后自动展开面板，便于截图核对
        if CommandLine.arguments.contains("--open-popover") {
            func snap(_ tag: String) {
                let w = statusItem.button?.window
                let line = "[\(tag)] btn=\(statusItem.button?.bounds ?? .zero) win=\(w?.frame ?? .zero) screen=\(w?.screen?.frame ?? .zero) shown=\(popover.popover.isShown)\n"
                if let h = FileHandle(forWritingAtPath: "/tmp/pp_window.log") {
                    h.seekToEndOfFile(); h.write(line.data(using: .utf8)!); h.closeFile()
                } else {
                    try? line.write(toFile: "/tmp/pp_window.log", atomically: true, encoding: .utf8)
                }
            }
            try? "".write(toFile: "/tmp/pp_window.log", atomically: true, encoding: .utf8)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { snap("before") }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.togglePopover()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { snap("after-toggle") }
            }
        }
    }

    // MARK: 状态栏

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        guard let button = statusItem.button else { return }
        button.action = #selector(statusClicked)
        button.target = self
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        updateStatusTitle()
    }

    private func setupMenu() {
        let menu = NSMenu()
        menu.addItem(withTitle: S.powerFlow.v(Settings.shared.lang), action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(withTitle: S.adapter.v(Settings.shared.lang), action: #selector(openAdapter), keyEquivalent: "")
        menu.addItem(withTitle: S.settings.v(Settings.shared.lang), action: #selector(openSettings), keyEquivalent: ",")
        menu.addItem(.separator())
        menu.addItem(withTitle: S.quit.v(Settings.shared.lang), action: #selector(quit), keyEquivalent: "q")
        menu.items.forEach { $0.target = self }
        statusItem.menu = nil // 右键时临时挂载
        self.menu = menu
    }
    private var menu: NSMenu!

    @objc private func statusClicked() {
        guard let event = NSApp.currentEvent else { return }
        if event.type == .rightMouseUp {
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil
            return
        }
        togglePopover()
    }

    private func setupPopover() {
        popover.onSizeChange = { [weak self] size in
            self?.popover.popover.contentSize = size
        }
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            guard let self, self.popover.popover.isShown else { return }
            self.popover.popover.performClose(nil)
        }
    }

    @objc private func togglePopover() {
        guard let button = statusItem.button else { return }
        if popover.popover.isShown {
            popover.popover.performClose(nil)
        } else {
            popover.refresh(power: snapshot, adapter: adapter, stats: stats, energy: energy)
            popover.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func openPanel() { open(at: 0) }
    @objc private func openAdapter() { open(at: 3) }
    @objc private func openSettings() { open(at: 4) }

    private func open(at idx: Int) {
        popover.select(idx)
        guard let button = statusItem.button else { return }
        if !popover.popover.isShown {
            popover.popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        let percent = snapshot.percent
        let watts = snapshot.isPluggedIn ? snapshot.wallW : snapshot.systemUsageW
        let color: NSColor = snapshot.isCharging ? .systemGreen
            : (snapshot.isPluggedIn ? .systemPurple : (percent <= 15 ? .systemRed : .labelColor))

        let image = Self.batteryImage(percent: percent, color: color, bolt: snapshot.isCharging)
        let mode = Settings.shared.menuBar

        let text = NSMutableAttributedString()
        func append(_ s: String) {
            text.append(NSAttributedString(string: s, attributes: [
                .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
                .foregroundColor: NSColor.labelColor,
            ]))
        }
        switch mode {
        case .pctAndW:
            append("\(percent)% ")
            let att = NSTextAttachment()
            att.image = image
            text.append(NSAttributedString(attachment: att))
            append(" \(fmtW(watts))W")
        case .pctOnly:
            append("\(percent)% ")
            let att = NSTextAttachment()
            att.image = image
            text.append(NSAttributedString(attachment: att))
        case .wOnly:
            append("\(fmtW(watts))W ")
            let att = NSTextAttachment()
            att.image = image
            text.append(NSAttributedString(attachment: att))
        case .iconOnly:
            let att = NSTextAttachment()
            att.image = image
            text.append(NSAttributedString(attachment: att))
        }
        button.attributedTitle = text
    }

    private func onTick() {
        HistoryStore.shared.record(snapshot, adapter: adapter)
        WidgetBridge.push(snapshot, adapter)
        Notifier.shared.evaluate(snapshot, adapter: adapter, lang: Settings.shared.lang)

        // 状态栏 1s 刷，弹窗 1s 刷（弹窗没开就不刷 UI）
        updateStatusTitle()
        if popover.popover.isShown {
            popover.refresh(power: snapshot, adapter: adapter, stats: stats, energy: energy)
        }
    }

    private func pump(force: Bool) {
        if force {
            updateStatusTitle()
            if popover.popover.isShown {
                popover.refresh(power: snapshot, adapter: adapter, stats: stats, energy: energy)
            }
        }
    }

    // MARK: 电池图标

    static func batteryImage(percent: Int, color: NSColor, bolt: Bool) -> NSImage {
        let w: CGFloat = 26, h: CGFloat = 13
        let bodyW: CGFloat = 22, tipW: CGFloat = 2.5, tipH: CGFloat = 5.5
        let inset: CGFloat = 1.6
        let img = NSImage(size: NSSize(width: w, height: h), flipped: false) { _ in
            guard let ctx = NSGraphicsContext.current?.cgContext else { return true }
            let body = CGRect(x: 0, y: 0, width: bodyW, height: h)
            let path = CGPath(roundedRect: body, cornerWidth: 3, cornerHeight: 3, transform: nil)
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(0.9)
            ctx.addPath(path)
            ctx.strokePath()

            let tip = CGRect(x: bodyW + 0.6, y: (h - tipH) / 2, width: tipW, height: tipH)
            ctx.setFillColor(color.cgColor)
            ctx.addPath(CGPath(roundedRect: tip, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil))
            ctx.fillPath()

            let fillW = (bodyW - inset * 2) * CGFloat(max(0, min(percent, 100))) / 100
            if fillW > 0.5 {
                let r = CGRect(x: inset, y: inset, width: fillW, height: h - inset * 2)
                ctx.addPath(CGPath(roundedRect: r, cornerWidth: 1.4, cornerHeight: 1.4, transform: nil))
                ctx.fillPath()
            }
            if bolt {
                ctx.saveGState()
                ctx.addPath(path)
                ctx.clip()
                ctx.setStrokeColor(NSColor.white.cgColor)
                ctx.setLineWidth(2.0)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                let b = CGMutablePath()
                b.move(to: CGPoint(x: 7.5, y: 1.5))
                b.addLine(to: CGPoint(x: 14.0, y: 5.2))
                b.addLine(to: CGPoint(x: 9.2, y: 6.0))
                b.addLine(to: CGPoint(x: 15.2, y: 10.6))
                ctx.addPath(b)
                ctx.strokePath()
                ctx.restoreGState()
            }
            return true
        }
        img.isTemplate = false
        return img
    }
}

// MARK: - 自检：离屏渲染每个面板成 PNG（真实数据），用于回归验证

final class ProbeEnergy {
    private var prev: [Int32: (UInt64, Date)] = [:]
    func prime() { _ = sample() }
    func sample() -> [ProcessEnergy] {
        let now = Date()
        let maxPids = 4096
        var pids = [pid_t](repeating: 0, count: maxPids)
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(maxPids * MemoryLayout<pid_t>.size))
        let n = Int(bytes) / MemoryLayout<pid_t>.size
        var out: [ProcessEnergy] = []
        for i in 0..<max(0, n) {
            let pid = pids[i]
            if pid <= 0 { continue }
            var info = rusage_info_v6()
            let ok = withUnsafeMutablePointer(to: &info) { p -> Bool in
                p.withMemoryRebound(to: rusage_info_t?.self, capacity: 1) { pp in
                    proc_pid_rusage(pid, RUSAGE_INFO_V6, pp) == 0
                }
            }
            guard ok else { continue }
            let nj = info.ri_energy_nj
            if let (p0, t0) = prev[pid], nj > p0 {
                let dt = now.timeIntervalSince(t0)
                if dt > 0 {
                    let mw = Double(nj - p0) / 1_000_000 / dt
                    if mw >= 1 { out.append(ProcessEnergy(id: pid, name: Self.name(pid), milliwatts: mw)) }
                }
            }
            prev[pid] = (nj, now)
        }
        return Array(out.sorted { $0.milliwatts > $1.milliwatts }.prefix(6))
    }
    private static func name(_ pid: Int32) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        if proc_name(pid, &buf, UInt32(buf.count)) > 0 {
            return (String(cString: buf) as NSString).lastPathComponent
        }
        return "pid \(pid)"
    }
}

func dbg(_ s: String) {
    FileHandle.standardError.write(("[selftest] " + s + "\n").data(using: .utf8)!)
}

extension PopoverController {
    func renderAll(to dir: String) {
        let (power, adapter) = Sampler.shared.sampleOnce()
        let stats = Sampler.shared.systemOnce()
        let probe = ProbeEnergy()
        probe.prime()
        Thread.sleep(forTimeInterval: 1.5)
        let energy = probe.sample()

        print("battery: \(power.percent)% charging=\(power.isCharging) plugged=\(power.isPluggedIn)")
        print(String(format: "power: wall=%.1fW system=%.1fW battery=%.1fW temp=%.1fC",
                     power.wallW, power.systemUsageW, power.batteryW, power.temperature))
        print(String(format: "health: %.1f%% cycles=%d design=%dmAh actual=%dmAh",
                     power.healthPercent, power.cycleCount, power.designCapacity, power.fullCapacity))
        print(String(format: "sys: cpu=%.0f%% gpu=%.0f%% mem=%.1f/%.0fGB",
                     stats.cpu, stats.gpu, stats.memUsedGB, stats.memTotalGB))
        if let a = adapter {
            print(String(format: "adapter: negotiated=%.0fW max=%.0fW %.0fV %.1fA pdos=%d",
                         a.negotiatedW, a.maxW, a.volts, a.amps, a.pdos.count))
            print("adapter-name: \(a.name.isEmpty ? "(none)" : a.name) / desc=\(a.adapterDescription)")
            print("verdict: \(a.verdict(snap: power).text)")
        } else {
            print("adapter: none")
        }
        print("energy: " + energy.prefix(3).map { "\($0.name) \(Int($0.milliwatts))mW" }.joined(separator: ", "))

        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for i in 0..<panelCount {
            select(i)
            let size = NSSize(width: D.width, height: panelsHeight(i))
            container.setFrameSize(size)
            container.needsLayout = true
            container.layoutSubtreeIfNeeded()
            refresh(power: power, adapter: adapter, stats: stats, energy: energy)
            container.needsLayout = true
            container.layoutSubtreeIfNeeded()
            print("panel\(i) fitting=\(panels[i].fittingSize) preferred=\(panels[i].preferredHeight)")
            if let rep = container.bitmapImageRepForCachingDisplay(in: container.bounds) {
                container.cacheDisplay(in: container.bounds, to: rep)
                if let data = rep.representation(using: .png, properties: [:]) {
                    let path = "\(dir)/panel\(i).png"
                    try? data.write(to: URL(fileURLWithPath: path))
                            print("wrote \(path) \(Int(size.width))x\(Int(size.height)) container=\(container.frame) panel=\(panels[i].frame) host=\(panelHost.frame) root=\(container.subviews.first?.frame ?? .zero)")
                }
            }
        }
    }
}

// MARK: - 入口

let app = NSApplication.shared
if let idx = CommandLine.arguments.firstIndex(of: "--selftest"), idx + 1 < CommandLine.arguments.count {
    dbg("boot")
    app.setActivationPolicy(.accessory)
    let pc = PopoverController()
    dbg("popover built")
    pc.renderAll(to: CommandLine.arguments[idx + 1])
    dbg("done")
    exit(0)
}
let delegate = AppDelegate()
app.delegate = delegate
app.run()
