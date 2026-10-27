import AppKit
import Foundation
import ServiceManagement

// MARK: - 弹窗

final class PopoverController: NSObject {
    let popover = NSPopover()
    let container = NSView()

    // 视图层级只搭一次，语言切换时只换"内容"，绝不重建 contentViewController
    // （重建会让 AppKit 把旧层和新层一起留在弹窗里，表现为中英文重影）
    private let root = NSView()
    private let headerTitle = label("", font: D.text(13, .medium), color: D.label)
    private let headerIcon = IconView("bolt.horizontal", size: 12, color: D.secondary)
    private let langButton = NSButton()
    private let panelHost = NSView()
    private var hostHeight: NSLayoutConstraint!
    private var tabBar: TabBar!
    /// tab 序号 → 面板序号。台式机没有电池，2/3 两页永远是空的，直接从 tab 栏里拿掉。
    private(set) var visibleTabs = [0, 1, 2, 3, 4]
    private var hasBattery = true
    private(set) var panels: [Panel] = []
    private var current = 0

    private let titles: [Tri] = [S.powerFlow, S.monitor, S.history, S.adapter, S.settings]
    private let symbols = ["bolt.horizontal", "cpu", "clock.arrow.circlepath", "powerplug", "gearshape"]

    var onSizeChange: ((NSSize) -> Void)?

    override init() {
        super.init()
        assembleOnce()
        rebuildPanels()
        show(0, resizeOnly: true)

        let vc = NSViewController()
        vc.view = container
        container.frame = NSRect(origin: .zero, size: sizeFor(current))
        popover.contentViewController = vc
        popover.behavior = .transient
        popover.animates = true
    }

    // MARK: 搭骨架（只跑一次）

    private func assembleOnce() {
        root.wantsLayer = true

        let glass = NSVisualEffectView()
        glass.material = .hudWindow
        glass.blendingMode = .behindWindow
        glass.state = .active
        glass.alphaValue = 0.55
        glass.translatesAutoresizingMaskIntoConstraints = false
        root.addSubview(glass)
        glass.pin(to: root)

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
        langButton.toolTip = "切换语言 / Switch language"
        langButton.wantsLayer = true
        langButton.layer?.cornerRadius = 5
        langButton.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.06).cgColor
        langButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 26).isActive = true
        langButton.heightAnchor.constraint(equalToConstant: 18).isActive = true
        refreshLangButton()

        let head = hstack([headerIcon, headerTitle, spacer(), langButton], spacing: 6)
        header.addSubview(head)
        head.pin(to: header, insets: .init(top: 0, left: D.pad, bottom: 0, right: D.pad))

        panelHost.translatesAutoresizingMaskIntoConstraints = false
        hostHeight = panelHost.heightAnchor.constraint(equalToConstant: 300)
        hostHeight.isActive = true

        tabBar = TabBar(items: zip(symbols, titles).map { TabBar.Item(symbol: $0.0, title: $0.1) })
        tabBar.onSelect = { [weak self] i in
            guard let self, self.visibleTabs.indices.contains(i) else { return }
            self.show(self.visibleTabs[i])
        }

        let stack = vstack([header, panelHost, tabBar], spacing: 0)
        root.addSubview(stack)
        stack.pin(to: root)
        header.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        panelHost.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        tabBar.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true

        container.addSubview(root)
        root.pin(to: container)
    }

    /// 只重建面板（语言变了才有必要）
    func rebuildPanels() {
        panels.forEach { $0.removeFromSuperview() }
        panels = [NowPanel(), MonitorPanel(), HistoryPanel(), AdapterPanel(), SettingsPanel()]
        for p in panels {
            p.translatesAutoresizingMaskIntoConstraints = false
            p.wantsLayer = true
            p.layer?.masksToBounds = true
            panelHost.addSubview(p)
            p.pin(to: panelHost)
        }
    }

    private func sizeFor(_ idx: Int) -> NSSize {
        NSSize(width: D.width, height: 38 + panels[idx].preferredHeight + 52)
    }

    // MARK: 切面板

    func select(_ idx: Int) { show(idx) }

    /// 没有电池的 Mac：只留 功率流 / 系统监控 / 设置
    func setHasBattery(_ v: Bool) {
        guard v != hasBattery else { return }
        hasBattery = v
        visibleTabs = v ? [0, 1, 2, 3, 4] : [0, 1, 4]
        tabBar.setItems(visibleTabs.map { TabBar.Item(symbol: symbols[$0], title: titles[$0]) })
        if !visibleTabs.contains(current) { show(0) } else { show(current) }
    }
    var panelCount: Int { panels.count }
    func panelsHeight(_ i: Int) -> CGFloat { sizeFor(i).height }

    private func show(_ idx: Int, resizeOnly: Bool = false) {
        guard panels.indices.contains(idx) else { return }
        current = idx
        for (i, p) in panels.enumerated() { p.isHidden = i != idx }
        headerTitle.stringValue = titles[idx].v(Settings.shared.lang)
        headerIcon.image = Icon.tinted(symbols[idx], color: D.secondary, size: 12)
        tabBar.highlight(visibleTabs.firstIndex(of: idx) ?? 0)
        if resizeOnly { tabBar.needsDisplay = true }

        hostHeight.constant = panels[idx].preferredHeight
        let size = sizeFor(idx)
        container.frame.size = size
        popover.contentSize = size
        onSizeChange?(size)
    }

    @objc private func cycleLang() {
        Settings.shared.lang = Settings.shared.lang.next
        NotificationCenter.default.post(name: .ppSettingsChanged, object: nil)
    }

    func refreshLangButton() {
        langButton.title = Settings.shared.lang.short
    }

    /// 语言切换：只换文案与面板，不碰视图结构
    func rebuild() {
        refreshLangButton()
        tabBar.relabel()
        let idx = current
        rebuildPanels()
        show(idx)
    }

    func refresh(power: PowerSnapshot, adapter: AdapterInfo?, stats: SystemStats, energy: [ProcessEnergy]) {
        guard panels.indices.contains(current) else { return }
        guard panels[current].needsLiveRefresh else { return }
        panels[current].refresh(power: power, adapter: adapter, stats: stats, energy: energy)
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
    // 建出来的时候要把"有没有电池"带进去，否则台式机上 tab 栏会多两个空页。
    // 仍然保持懒加载：PopoverController 会建 NSPopover 层级，太早建状态栏窗口高度会变 0。
    private var _popover: PopoverController?
    private var popover: PopoverController {
        if _popover == nil {
            let pc = PopoverController()
            pc.setHasBattery(hasBattery)
            _popover = pc
        }
        return _popover!
    }
    private var hasBattery = true
    private var eventMonitor: Any?
    private var snapshot = PowerSnapshot()
    private var adapter: AdapterInfo?
    private var stats = SystemStats()
    private var energy: [ProcessEnergy] = []
    private var lastUI = Date.distantPast
    private let watcher = PowerSourceWatcher()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // --derive-test：三个数怎么合成是纯函数，不用插拔电源也能验
        if CommandLine.arguments.contains("--derive-test") {
            var fails = 0
            func near(_ name: String, _ got: Double, _ want: Double) {
                let ok = abs(got - want) <= 0.06
                if !ok { fails += 1 }
                print("\(ok ? "✓" : "✗") \(name): \(String(format: "%.2f", got)) (期望 \(String(format: "%.2f", want)))")
            }
            // 1. 电池取数：顶层可信就用顶层；顶层缺了才用 Amperage×Voltage
            near("电池·顶层优先", PowerMath.pickBattery(top: 44.3, ampereVolt: 10.0, telemetry: 21.3) ?? -1, 44.3)
            near("电池·缺顶层回退", PowerMath.pickBattery(top: nil, ampereVolt: 10.01, telemetry: 21.3) ?? -1, 10.01)
            // 2. 遥测溢出（uint64 回绕成 1.8e16）和 NaN 必须当没读到，不能画到界面上
            near("遥测溢出·丢弃", PowerMath.pickBattery(top: nil, ampereVolt: nil, telemetry: 1.8446744e16) ?? -1, -1)
            near("负 PSTR·丢弃", PowerMath.sanePositive(-4.3) ?? -1, -1)
            near("超量程·丢弃", PowerMath.sane(1.8e16) ?? -1, -1)

            // 3. 充电方向：实测 43% 插着 30W 头，IsCharging=0 但电流 +6.3W
            near("方向·flag=0 但电流为正", PowerMath.chargeState(signedBatteryW: 6.3, flag: false).charging ? 1 : 0, 1)
            near("方向·电流为负 仍在放", PowerMath.chargeState(signedBatteryW: -6.3, flag: true).draining ? 1 : 0, 1)
            near("方向·电流为负 不算充", PowerMath.chargeState(signedBatteryW: -6.3, flag: true).charging ? 1 : 0, 0)
            near("方向·满电涓流 flag=1", PowerMath.chargeState(signedBatteryW: 0.1, flag: true).charging ? 1 : 0, 1)
            near("方向·满电静置", PowerMath.chargeState(signedBatteryW: 0.1, flag: false).charging ? 1 : 0, 0)

            // 4. 墙插恒等式：墙插 = 系统 + 电池，永远对得上（PDTR 只是兜底）
            near("恒等·插电", PowerMath.pickWall(contract: 27.9, telemetry: 25.7, plugged: true,
                                                system: 6.1, battery: 12.6, draining: false), 18.7)
            near("恒等·补充供电", PowerMath.pickWall(contract: 2.4, telemetry: 2.4, plugged: true,
                                                 system: 9.2, battery: 6.8, draining: true), 2.4)
            near("恒等·放电墙插为 0", PowerMath.pickWall(contract: 0, telemetry: 0, plugged: false,
                                                    system: 8.9, battery: 8.9, draining: true), 0)
            near("恒等·系统全读不到退回合约值", PowerMath.pickWall(contract: 27.9, telemetry: 25.7, plugged: true,
                                                          system: 0, battery: 0, draining: false), 27.9)
            print(fails == 0 ? "全部通过" : "\(fails) 项不符")
            exit(fails == 0 ? 0 : 1)
        }
        // --widget-text：小组件加不到桌面上也能核对三语文案
        if CommandLine.arguments.contains("--widget-text") {
            for lang in ["zh", "tw", "en"] {
                let t = WText(lang: lang)
                print("--- \(lang) ---")
                print("状态: \(t.charging) / \(t.full) / \(t.pluggedIn) / \(t.discharging) / \(t.assisting) / \(t.directPower)")
                print("档位: \(t.gear(52, 60))  \(t.kitMax(60))  \(t.health("92"))")
                print("功率: \(t.wall(52))  \(t.system(12))")
                print("电池: \(t.into("39.5", t.toFull(64)))")
                print("      \(t.out("6.8", t.rest(182)))")
                print("无电池: \(t.noBattery)   时间: \(t.rest(0)) | \(t.rest(65535)) | \(t.rest(5))")
                var cases: [(String, WidgetSnapshot)] = []
                func mk(_ name: String, _ build: (inout WidgetSnapshot) -> Void) {
                    var w = WidgetSnapshot(); w.lang = lang; build(&w); cases.append((name, w))
                }
                mk("充电 87%") { $0.percent = 87; $0.charging = true; $0.plugged = true }
                mk("满电静置") { $0.percent = 100; $0.plugged = true }
                mk("补充供电") { $0.percent = 43; $0.plugged = true; $0.draining = true }
                mk("电池放电") { $0.percent = 62 }
                mk("台式机") { $0.hasBattery = false; $0.plugged = true }
                print("状态映射: " + cases.map { "\($0.0)→\($0.1.stateText)" }.joined(separator: " · "))
            }
            exit(0)
        }

        // 命令行开关：--login=on / --login=off / --login=status
        // 用来在没有界面自动化权限时核对登录项，装完直接跑一条。
        if let arg = CommandLine.arguments.first(where: { $0.hasPrefix("--login=") }) {
            let mode = String(arg.dropFirst("--login=".count))
            switch mode {
            case "on":  print(LoginItem.set(true) ? "login=on" : "login=failed")
            case "off": print(LoginItem.set(false) ? "login=off" : "login=failed")
            default:    print("login=\(LoginItem.isOn ? "on" : "off") status=\(SMAppService.mainApp.status.rawValue)")
            }
            if mode != "status" { print("status=\(SMAppService.mainApp.status.rawValue)") }
            exit(0)
        }
        let skip = Set((CommandLine.arguments.first(where: { $0.hasPrefix("--skip=") })?
            .replacingOccurrences(of: "--skip=", with: "") ?? "").split(separator: ",").map(String.init))
        if !skip.contains("history") {
            HistoryStore.shared.open()
            HistoryStore.shared.prune(days: Settings.shared.retentionDays)
            HistoryStore.shared.checkpoint()
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
            self.hasSampled = true
            self.snapshot = s
            self.adapter = a
            // 台式机没有电池：tab 栏别留两个永远空的页
            self.hasBattery = s.hasBattery
            self._popover?.setHasBattery(s.hasBattery)
            self.onTick()
        }
        Sampler.shared.onSystem = { [weak self] st in self?.stats = st }
        Sampler.shared.onEnergy = { [weak self] e in self?.energy = e }
        LoginItem.repairIfNeeded()
        if !skip.contains("sampler") { Sampler.shared.start(interval: Settings.shared.interval) }

        NotificationCenter.default.addObserver(forName: .ppSettingsChanged, object: nil, queue: .main) { [weak self] _ in
            guard let self else { return }
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
        // 压测：反复开关弹窗，看窗口/视图/RSS 会不会越开越多
        if let cyc = CommandLine.arguments.first(where: { $0.hasPrefix("--cycle=") }),
           let n = Int(cyc.replacingOccurrences(of: "--cycle=", with: "")) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                for i in 0..<n {
                    DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.30) {
                        self.togglePopover()
                        if i == n - 1 {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                                let line = "done n=\(n) windows=\(NSApp.windows.count) subviews=\(self.popover.container.subviews.count) shown=\(self.popover.popover.isShown)\n"
                                try? line.write(toFile: "/tmp/pp_cycle.txt", atomically: true, encoding: .utf8)
                            }
                        }
                    }
                }
            }
        }
        if CommandLine.arguments.contains("--open-popover") {
            func snap(_ tag: String) {
                let winCount = NSApp.windows.count
                let subCount = popover.container.subviews.count
                _ = winCount
                let w = statusItem.button?.window
                let line = "[\(tag)] shown=\(popover.popover.isShown) containerSubviews=\(subCount) windows=\(winCount) win=\(w?.frame ?? .zero)\n"
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
                if let t = CommandLine.arguments.first(where: { $0.hasPrefix("--tab=") }),
                   let n = Int(t.replacingOccurrences(of: "--tab=", with: "")) {
                    self.popover.select(n)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { snap("after-toggle") }
                // 连切三次语言，确认不会叠层
                for (i, lang) in [Lang.tw, .en, .zh].enumerated() {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0 + Double(i) * 0.6) {
                        Settings.shared.lang = lang
                        NotificationCenter.default.post(name: .ppSettingsChanged, object: nil)
                    }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.4) { snap("after-3-lang-switch") }
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

    private var lastTitleKey = ""
    private var hasSampled = false

    /// 菜单栏标题的组装单独拆出来：状态栏和自检渲染共用同一份代码，
    /// 否则"渲染出来对、真机不对"这种问题永远测不出来。
    static func statusTitle(percent: Int, watts: Double, charging: Bool, plugged: Bool,
                            mode: Settings.MenuBarMode, image: NSImage) -> NSAttributedString {
        let font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold)
        let text = NSMutableAttributedString()
        func append(_ s: String) {
            text.append(NSAttributedString(string: s, attributes: [
                .font: font,
                .foregroundColor: NSColor.labelColor,
            ]))
        }
        // NSTextAttachment 默认把图片底边压在基线上；图标比文字高，就会整体偏上。
        // 按 capHeight 把图标往下挪，让图标和文字的视觉中心对齐。
        func iconAttachment() -> NSAttributedString {
            let att = NSTextAttachment()
            att.image = image
            let iw = image.size.width, ih = image.size.height
            let dy = (font.capHeight - ih) / 2
            att.bounds = CGRect(x: 0, y: dy, width: iw, height: ih)
            return NSAttributedString(attachment: att)
        }
        switch mode {
        case .pctAndW:
            append("\(percent)% ")
            text.append(iconAttachment())
            append(" \(fmtW(watts))W")
        case .pctOnly:
            append("\(percent)% ")
            text.append(iconAttachment())
        case .wOnly:
            append("\(fmtW(watts))W ")
            text.append(iconAttachment())
        case .iconOnly:
            text.append(iconAttachment())
        }
        return text
    }

    private func updateStatusTitle() {
        guard let button = statusItem.button else { return }
        // 第一帧采样之前 snapshot 是默认值（hasBattery=false、percent=0），
        // 这时候照着它画会出现「插头闪一下」或「0%」，宁可不画
        guard hasSampled else { return }
        // 台式机没有电池：插座 + 整机功率（SMC 读得到时），读不到退回落 CPU 占用
        if !snapshot.hasBattery {
            let watts = snapshot.desktopW
            let cpu = Int(stats.cpu.rounded())
            let text = watts > 0 ? "\(Int(watts.rounded())) W" : "\(cpu)%"
            let key = "nobattery|\(text)"
            guard key != lastTitleKey else { return }
            lastTitleKey = key
            if button.image == nil || button.image?.accessibilityDescription != "PowerPulse" {
                button.image = NSImage(systemSymbolName: "powerplug.fill", accessibilityDescription: "PowerPulse")
                button.image?.isTemplate = true
            }
            button.attributedTitle = NSAttributedString(
                string: " \(text)",
                attributes: [.font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                             .foregroundColor: NSColor.labelColor])
            button.toolTip = S.noBattery.v(Settings.shared.lang) + " · "
                + (watts > 0 ? "SMC PSTR" : S.cpuLoad.v(Settings.shared.lang))
            return
        }
        // 有电池：先把插头图标摘掉，否则会和电池图标并排出现
        if button.image != nil { button.image = nil }
        let percent = snapshot.percent
        let watts = snapshot.isPluggedIn ? snapshot.wallW : snapshot.systemUsageW
        let key = "\(percent)|\(Int(watts.rounded()))|\(snapshot.isCharging)|\(Settings.shared.menuBar.rawValue)"
        guard key != lastTitleKey else { return }
        lastTitleKey = key
        let color: NSColor = snapshot.isCharging ? .systemGreen
            : (snapshot.isPluggedIn ? .systemPurple : (percent <= 15 ? .systemRed : .labelColor))
        let image = Self.cachedBatteryImage(percent: percent, color: color, bolt: snapshot.isCharging)
        button.attributedTitle = Self.statusTitle(percent: percent, watts: watts,
                                                  charging: snapshot.isCharging,
                                                  plugged: snapshot.isPluggedIn,
                                                  mode: Settings.shared.menuBar, image: image)
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

    private static var imageCache: [String: NSImage] = [:]

    static func cachedBatteryImage(percent: Int, color: NSColor, bolt: Bool) -> NSImage {
        let key = "\(percent)|\(color.description)|\(bolt)"
        if let hit = imageCache[key] { return hit }
        if imageCache.count > 60 { imageCache.removeAll() }
        let img = batteryImage(percent: percent, color: color, bolt: bolt)
        imageCache[key] = img
        return img
    }

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

/// 递归找出超出父视图边界 / 宽度不够的控件
func auditOverflow(_ v: NSView, path: String = "") -> [String] {
    var out: [String] = []
    // 滚动视图里的文档视图本来就会比裁剪区高，那不是溢出
    if v is NSScrollView || v is NSClipView { return [] }
    for sub in v.subviews where !sub.isHidden {
        let f = sub.frame
        let b = v.bounds
        let name = String(describing: type(of: sub))
        // 容差 3pt：NSTextField 的 alignment rect 天然带 ±2pt 内缩，不算溢出
        let tol: CGFloat = 3
        let escaped = f.maxX > b.width + tol || f.minX < -tol || f.maxY > b.height + tol || f.minY < -tol
        if escaped {
            out.append("\(path)/\(name) frame=\(f) parent=\(b.size)")
        }
        out += auditOverflow(sub, path: path + "/" + name)
    }
    return out
}

func dbg(_ s: String) {
    FileHandle.standardError.write(("[selftest] " + s + "\n").data(using: .utf8)!)
}

extension PopoverController {
    func renderAll(to dir: String) {
        HistoryStore.shared.open()
        var (power, adapter) = Sampler.shared.sampleOnce()
        if CommandLine.arguments.contains("--supplement") {
            // 插着弱充电器、电池在补：两路进、一路出
            power = .demoSupplement()
            adapter = .demoWeakAdapter()
        } else if CommandLine.arguments.contains("--plugged") {
            power = .demoPlugged()
            adapter = .demoAdapter()
        }
        if CommandLine.arguments.contains("--nobattery") {
            power = PowerSnapshot()      // 台式机：没有电池
            power.hasBattery = false
            let dw = SMCPower.systemWatts() ?? 0           // 本机 SMC 有就真读，没有就 0
            power.desktopW = dw
            power.wallW = dw
            power.systemLoadW = dw
            adapter = nil
        }
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

        setHasBattery(power.hasBattery)

        func render(_ tag: String) {
            for i in visibleTabs {
                select(i)
                let size = NSSize(width: D.width, height: panelsHeight(i))
                container.setFrameSize(size)
                container.needsLayout = true
                container.layoutSubtreeIfNeeded()
                refresh(power: power, adapter: adapter, stats: stats, energy: energy)
                container.needsLayout = true
                container.layoutSubtreeIfNeeded()
                if let rep = container.bitmapImageRepForCachingDisplay(in: container.bounds) {
                    container.cacheDisplay(in: container.bounds, to: rep)
                    if let data = rep.representation(using: .png, properties: [:]) {
                        let prefix = CommandLine.arguments.contains("--dark") ? "dark-" : "light-"
                        let path = "\(dir)/\(prefix)\(tag)-\(i).png"
                        try? data.write(to: URL(fileURLWithPath: path))
                    }
                }
            }
            print("[render] \(tag) container.subviews=\(container.subviews.count)")
            for i in visibleTabs {
                let issues = auditOverflow(panels[i])
                if !issues.isEmpty {
                    print("  ⚠️ panel\(i) overflow \(issues.count):")
                    issues.prefix(6).forEach { print("     \($0)") }
                }
            }
        }

        let originalLang = Settings.shared.lang
        defer { Settings.shared.lang = originalLang }
        for lang in Lang.allCases {
            Settings.shared.lang = lang
            rebuild()
            render(lang.rawValue)
        }

        // 反复切语言，视图数量必须保持恒定（以前会越切越叠）
        Settings.shared.lang = Lang.allCases[0]
        rebuild()
        let before = container.subviews.count
        for _ in 0..<6 { rebuild() }
        print("[rebuild] 7 次重建后 container.subviews \(before) -> \(container.subviews.count)（应相等）")
        render("final")
        print("wrote panels to \(dir)")
    }
}

// MARK: - 菜单栏标题离屏渲染（像素级核对图标与文字的对齐）

enum StatusBarRender {
    static func run(dir: String) {
        // 台式机：插座 + CPU%，电池机：电池图标 + 百分比
        if CommandLine.arguments.contains("--nobattery") {
            try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
            let watts = SMCPower.systemWatts()
            let demos: [String] = (watts.map { [String(format: "%.0f W", $0)] } ?? []) + ["7%", "38%", "86%"]
            for label in demos {
                // 渲染到纯位图时没有系统着色，template 图会黑底黑图，得自己上色
                let plug = Icon.tinted("powerplug.fill", color: .labelColor, size: 13)
                let t = NSMutableAttributedString()
                if let plug {
                    let att = NSTextAttachment()
                    att.image = plug
                    t.append(NSAttributedString(attachment: att))
                }
                t.append(NSAttributedString(string: "\(label)", attributes: [
                    .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular),
                    .foregroundColor: NSColor.labelColor]))
                let sz = t.size()
                let W = Int(ceil(sz.width)) + 12, H = 22
                guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W * 2, pixelsHigh: H * 2,
                                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                                 isPlanar: false, colorSpaceName: .deviceRGB,
                                                 bytesPerRow: 0, bitsPerPixel: 0) else { continue }
                rep.size = NSSize(width: W, height: H)
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
                if !CommandLine.arguments.contains("--alpha") {
                    NSColor.black.setFill(); NSRect(x: 0, y: 0, width: W, height: H).fill()
                }
                t.draw(at: NSPoint(x: 6, y: (CGFloat(H) - sz.height) / 2 + 1))
                NSGraphicsContext.restoreGraphicsState()
                if let data = rep.representation(using: .png, properties: [:]) {
                    let safe = label.replacingOccurrences(of: " ", with: "")
                    try? data.write(to: URL(fileURLWithPath: dir + "/status-desktop-\(safe).png"))
                }
                print("[status] desktop-\(label) size=\(sz)")
            }
            return
        }
        let cases: [(String, Int, Double, Bool, Bool)] = [
            ("87-52w", 87, 52, true, true),
            ("45-12w", 45, 12, true, true),
            ("100-0w", 100, 0, false, false),
        ]
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        for (name, pct, w, ch, plug) in cases {
            let color: NSColor = ch ? .systemGreen : (plug ? .systemPurple : .labelColor)
            let img = AppDelegate.cachedBatteryImage(percent: pct, color: color, bolt: ch)
            let title = AppDelegate.statusTitle(percent: pct, watts: w, charging: ch,
                                                plugged: plug, mode: .pctAndW, image: img)
            let sz = title.size()
            let W = Int(ceil(sz.width)) + 12
            let H = 22
            guard let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: W * 2, pixelsHigh: H * 2,
                                             bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
                                             isPlanar: false, colorSpaceName: .deviceRGB,
                                             bytesPerRow: 0, bitsPerPixel: 0) else { continue }
            rep.size = NSSize(width: W, height: H)
            NSGraphicsContext.saveGraphicsState()
            NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
            if !CommandLine.arguments.contains("--alpha") {
                NSColor.black.setFill()
                NSRect(x: 0, y: 0, width: W, height: H).fill()
            }
            title.draw(at: NSPoint(x: 6, y: (CGFloat(H) - sz.height) / 2 + 1))
            NSGraphicsContext.restoreGraphicsState()
            if let data = rep.representation(using: .png, properties: [:]) {
                try? data.write(to: URL(fileURLWithPath: dir + "/status-\(name).png"))
            }
            print("[status] \(name) textSize=\(sz) imageSize=\(img.size)")
        }
    }
}

// MARK: - 入口

let app = NSApplication.shared
if let si = CommandLine.arguments.firstIndex(of: "--statusbar"), si + 1 < CommandLine.arguments.count {
    if CommandLine.arguments.contains("--dark") {
        app.appearance = NSAppearance(named: .darkAqua)
    } else {
        app.appearance = NSAppearance(named: .aqua)
    }
    StatusBarRender.run(dir: CommandLine.arguments[si + 1])
    exit(0)
}
if CommandLine.arguments.contains("--smc-probe") {
    // 台式机上跑一次，就知道 SMC 有没有可用的功率键
    for line in SMCPower.probe() { print(line) }
    exit(0)
}
if CommandLine.arguments.contains("--export") {
    // 无界面验证 CSV 导出：写失败/无数据/成功 三种结果都要能区分
    HistoryStore.shared.open()
    switch HistoryStore.shared.exportCSV() {
    case .ok(let u):   print("[export] ok \(u.path)")
    case .empty:       print("[export] empty")
    case .failed(let e): print("[export] failed \(e)")
    }
    exit(0)
}
if let idx = CommandLine.arguments.firstIndex(of: "--selftest"), idx + 1 < CommandLine.arguments.count {
    dbg("boot")
    app.setActivationPolicy(.accessory)
    // 深色/浅色要在建视图之前设定，否则 layer 的 CGColor 会按旧外观解析
    if CommandLine.arguments.contains("--dark") {
        app.appearance = NSAppearance(named: .darkAqua)
    } else if CommandLine.arguments.contains("--light") {
        app.appearance = NSAppearance(named: .aqua)
    }
    let pc = PopoverController()
    dbg("popover built")
    pc.renderAll(to: CommandLine.arguments[idx + 1])
    dbg("done")
    exit(0)
}
let delegate = AppDelegate()
app.delegate = delegate
app.run()
