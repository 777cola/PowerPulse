import AppKit

// MARK: - 面板基类

class Panel: NSView {
    var preferredHeight: CGFloat { 300 }
    /// 只有实时数据的面板才需要每秒刷新
    var needsLiveRefresh: Bool { true }
    override var isFlipped: Bool { true }
    var lang: Lang { Settings.shared.lang }

    func refresh(power: PowerSnapshot, adapter: AdapterInfo?, stats: SystemStats, energy: [ProcessEnergy]) {}
}

private func wrapScroll(_ content: NSView, height: CGFloat) -> NSScrollView {
    let doc = NSView()
    doc.translatesAutoresizingMaskIntoConstraints = false
    doc.addSubview(content)
    content.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
        content.leadingAnchor.constraint(equalTo: doc.leadingAnchor),
        content.trailingAnchor.constraint(equalTo: doc.trailingAnchor),
        content.topAnchor.constraint(equalTo: doc.topAnchor),
        content.bottomAnchor.constraint(equalTo: doc.bottomAnchor),
    ])
    let sv = NSScrollView()
    sv.translatesAutoresizingMaskIntoConstraints = false
    sv.drawsBackground = false
    sv.hasVerticalScroller = true
    sv.autohidesScrollers = true
    sv.documentView = doc
    if height > 0 { sv.heightAnchor.constraint(equalToConstant: height).isActive = true }
    doc.widthAnchor.constraint(equalTo: sv.widthAnchor).isActive = true
    return sv
}

// MARK: - 现在（功率流）

final class NowPanel: Panel {
    private let flow = FlowView()
    private let wallCard = MetricCard(title: S.wall.v(Settings.shared.lang), symbol: "powerplug.fill", color: D.purple)
    private let sysCard = MetricCard(title: S.systemUse.v(Settings.shared.lang), symbol: "desktopcomputer", color: D.blue)
    private let batCard = MetricCard(title: S.batteryOut.v(Settings.shared.lang), symbol: "battery.25", color: D.orange)
    private let stateCard = MetricCard(title: S.battery.v(Settings.shared.lang), symbol: "battery.100", color: D.green)

    private let adapterLine = label("", font: D.text(10), color: D.secondary)
    private let adapterValue = label("", font: D.num(10, .medium), color: D.label, align: .right)
    private let bar = LevelBar()
    private let adapterBox = NSView()

    override var preferredHeight: CGFloat { 264 }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        flow.translatesAutoresizingMaskIntoConstraints = false
        flow.heightAnchor.constraint(equalToConstant: 132).isActive = true

        let cards = CardRow([wallCard, sysCard, batCard, stateCard], spacing: 7, height: 58)

        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.height = 4
        adapterBox.translatesAutoresizingMaskIntoConstraints = false
        let adapterStack = vstack([hstack([adapterLine, spacer(), adapterValue], spacing: 6), bar], spacing: 5)
        adapterBox.addSubview(adapterStack)
        adapterStack.pin(to: adapterBox, insets: .init(top: 8, left: 11, bottom: 8, right: 11))
        adapterBox.wantsLayer = true
        adapterBox.layer?.cornerRadius = 9
        adapterBox.layer?.backgroundColor = D.cardFill.cgColor

        let root = vstack([flow, cards, adapterBox], spacing: 10)
        addSubview(root)
        root.pin(to: self, insets: .init(top: 2, left: D.pad, bottom: 8, right: D.pad))
        root.setCustomSpacing(6, after: flow)
        cards.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        adapterBox.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        flow.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override var isHidden: Bool {
        didSet { syncAnimation() }
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        syncAnimation()
    }

    /// 不在前台就停掉动画 —— 隐藏的面板也有 window，光靠 viewDidMoveToWindow 停不下来
    private func syncAnimation() {
        if isHidden || window == nil { flow.stopAnimating() } else { flow.startAnimating() }
    }

    override func refresh(power s: PowerSnapshot, adapter a: AdapterInfo?, stats: SystemStats, energy: [ProcessEnergy]) {
        flow.update(s, a)

        // 台式机（Mac Studio / mini / Pro）：没有电池，四张卡都不能写 0 / 放电中
        if !s.hasBattery {
            wallCard.update(value: "—");  wallCard.setDimmed(true)
            sysCard.update(value: s.desktopW > 0 ? String(format: "%.1f W", s.desktopW) : "—")
            // 没有电池，这两张卡留着只会让人以为读不到数
            batCard.isHidden = true
            stateCard.isHidden = true
            adapterBox.isHidden = true
            return
        }

        batCard.isHidden = false
        stateCard.isHidden = false
        wallCard.update(value: s.isPluggedIn ? String(format: "%.1f W", s.wallW) : "—")
        wallCard.setDimmed(!s.isPluggedIn)
        sysCard.update(value: String(format: "%.1f W", s.systemUsageW))

        if s.isCharging {
            batCard.update(title: S.chargePower.v(lang), value: String(format: "%.1f W", s.batteryChargeW), valueColor: D.green)
        } else {
            batCard.update(title: s.isPluggedIn ? S.batteryOut.v(lang) : S.batteryOut.v(lang),
                           value: String(format: "%.1f W", s.batteryDischargeW), valueColor: D.orange)
        }
        // 状态当小标题、电量当大字：英文 "Battery 100%" 这种长标题会把卡片挤爆
        stateCard.update(title: s.statusTextKey.v(lang),
                         value: "\(s.percent)%",
                         valueColor: s.isCharging ? D.green : (s.percent <= 15 ? D.red : D.label))

        if let a, s.isPluggedIn {
            adapterBox.isHidden = false
            // 档位 = PD 协商到的那一档；取电 = 实际墙插输入，两者不是一回事
            adapterLine.stringValue = "\(S.adapter.v(lang)) · \(S.gear.v(lang)) \(fmtW(a.negotiatedW))/\(fmtW(a.maxW))W"
            adapterValue.stringValue = "\(S.draw.v(lang)) \(fmtW(s.wallW))W"
            let load = a.maxW > 0 ? s.wallW / a.maxW : 0
            bar.ratio = CGFloat(min(max(load, 0), 1))
            bar.color = load > 0.9 ? D.green : D.blue
        } else {
            adapterBox.isHidden = true
        }
    }
}

// MARK: - 系统监控

final class MonitorPanel: Panel {
    private let cpuRow = KVRow("CPU", symbol: "cpu", value: "—")
    private let gpuRow = KVRow("GPU", symbol: "rectangle.on.rectangle", value: "—")
    private let memRow = KVRow(S.mem.v(Settings.shared.lang), symbol: "memorychip", value: "—")
    private let cpuBar = LevelBar(), gpuBar = LevelBar(), memBar = LevelBar()
    private let chart = LineChartView()
    private let curveTitle = SectionTitle("", symbol: "waveform.path.ecg")
    private let energyStack = NSStackView()
    private var energyRows: [KVRow] = []
    /// 缓冲按"保留 5 分钟"给容量，而不是写死点数：
    /// 1 秒采样 = 300 点，2 秒采样 = 150 点。之前写死 90 点（默认 1 秒下只有 90 秒），
    /// 跟界面上/README 里说的「5 分钟历史」对不上。
    private let liveBuffer = RingBuffer(capacity: max(60, Int(300 / max(Settings.shared.interval, 0.5))))
    private var lastTickMinute = -1

    override var preferredHeight: CGFloat { 376 }

    /// 自检/拍图用：--plugged 时用一条合成曲线把 5 分钟缓冲填满，
    /// 否则功率曲线永远「暂无记录」，截图没法用。
    private func seedDemoCurveIfNeeded() {
        guard CommandLine.arguments.contains("--plugged"), liveBuffer.count < 5 else { return }
        let n = liveBuffer.capacity
        for i in 0..<n {
            let t = Double(i) / Double(max(n - 1, 1))
            let v = 24 + 30 * (0.5 + 0.5 * sin(t * 9.4)) + 6 * sin(t * 33)
            liveBuffer.append(max(4, min(94, v)))
        }
    }

    /// 曲线的时间刻度：用 Date 算，跨零点由 DateFormatter 进位（不会出现 24:16、27:16）。
    /// 每分钟才重建一次，避免每秒 300 次字符串格式化。
    private func updateTimeTicks() {
        let minute = Int(Date().timeIntervalSince1970 / 60)
        guard minute != lastTickMinute else { return }
        lastTickMinute = minute
        let span = Double(liveBuffer.capacity) * max(Settings.shared.interval, 0.5)
        let now = Date()
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        chart.ticks = [
            (0, f.string(from: now.addingTimeInterval(-span))),
            (0.5, f.string(from: now.addingTimeInterval(-span / 2))),
            (1, f.string(from: now)),
        ]
    }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        cpuBar.color = D.blue; gpuBar.color = D.purple; memBar.color = D.green
        [cpuBar, gpuBar, memBar].forEach { $0.translatesAutoresizingMaskIntoConstraints = false; $0.height = 4 }

        let gauges = vstack([
            cpuRow, cpuBar,
            gpuRow, gpuBar,
            memRow, memBar,
        ], spacing: 4)
        gauges.setCustomSpacing(9, after: cpuBar)
        gauges.setCustomSpacing(9, after: gpuBar)

        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.heightAnchor.constraint(equalToConstant: 74).isActive = true
        chart.color = D.blue

        energyStack.orientation = .vertical
        energyStack.alignment = .leading
        energyStack.spacing = 2
        energyStack.translatesAutoresizingMaskIntoConstraints = false

        let root = vstack([
            SectionTitle(S.cpuLoad.v(lang), symbol: "gauge.medium"),
            gauges,
            curveTitle,
            chart,
            SectionTitle(S.energyTitle.v(lang), symbol: "bolt.batteryblock"),
            energyStack,
        ], spacing: 7)
        addSubview(root)
        root.pin(to: self, insets: .init(top: 6, left: D.pad, bottom: 8, right: D.pad))
        root.setCustomSpacing(2, after: root.arrangedSubviews[0])
        root.setCustomSpacing(10, after: gauges)
        root.setCustomSpacing(2, after: root.arrangedSubviews[3])
        root.setCustomSpacing(10, after: chart)
        root.setCustomSpacing(2, after: root.arrangedSubviews[5])

        cpuBar.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        gpuBar.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        memBar.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        chart.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        energyStack.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func refresh(power: PowerSnapshot, adapter: AdapterInfo?, stats: SystemStats, energy: [ProcessEnergy]) {
        seedDemoCurveIfNeeded()
        cpuRow.setValue(String(format: "%.0f%%", stats.cpu))
        gpuRow.setValue(String(format: "%.0f%%", stats.gpu))
        memRow.setValue(String(format: "%.1f / %.0f GB", stats.memUsedGB, stats.memTotalGB))
        cpuBar.ratio = CGFloat(stats.cpu / 100)
        gpuBar.ratio = CGFloat(stats.gpu / 100)
        memBar.ratio = CGFloat(stats.memPercent / 100)

        // 台式机读不到 SystemPowerIn，曲线改画 CPU 占用，否则永远是一条 0W 的平线
        let showCPU = !power.hasBattery
        curveTitle.set((showCPU ? S.cpuCurve : S.powerCurve).v(lang))
        chart.unit = showCPU ? "%" : "W"
        liveBuffer.append(showCPU ? stats.cpu : power.systemUsageW)
        chart.set(liveBuffer.array)
        updateTimeTicks()

        // 耗电排行
        let top = Array(energy.prefix(5))
        if top.count != energyRows.count {
            energyRows.forEach { $0.removeFromSuperview() }
            energyRows = top.map { _ in
                let r = KVRow("", symbol: "app.dashed", value: "—")
                energyStack.addArrangedSubview(r)
                r.widthAnchor.constraint(equalTo: energyStack.widthAnchor).isActive = true
                return r
            }
        }
        for (i, e) in top.enumerated() where i < energyRows.count {
            energyRows[i].setKey(e.name)
            energyRows[i].setValue(String(format: "%.0f mW", e.milliwatts), color: e.milliwatts > 300 ? D.orange : D.label)
        }
    }
}

// MARK: - 充电历史

final class HistoryPanel: Panel {
    private let inCard = MetricCard(title: S.totalIn.v(Settings.shared.lang), symbol: "bolt.fill", color: D.green)
    private let avgCard = MetricCard(title: S.avgPower.v(Settings.shared.lang), symbol: "chart.line.uptrend.xyaxis", color: D.blue)
    private let peakCard = MetricCard(title: S.peakPower.v(Settings.shared.lang), symbol: "arrow.up.right", color: D.orange)
    private let durCard = MetricCard(title: S.duration.v(Settings.shared.lang), symbol: "clock", color: D.label)
    private let chart = LineChartView()
    private let weekChart = BarChartView()
    private let weekTitle = SectionTitle("", symbol: "calendar")
    private let exportButton = PillButton(S.exportCSV.v(Settings.shared.lang), target: nil, action: #selector(HistoryPanel.exportTapped))
    private let empty = label("", font: D.text(11), color: D.tertiary)

    override var preferredHeight: CGFloat { 336 }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        exportButton.target = self
        chart.color = D.green
        chart.translatesAutoresizingMaskIntoConstraints = false
        chart.heightAnchor.constraint(equalToConstant: 78).isActive = true
        weekChart.translatesAutoresizingMaskIntoConstraints = false
        weekChart.heightAnchor.constraint(equalToConstant: 84).isActive = true
        weekTitle.set("\(S.last7.v(lang)) · \(S.dailyWh.v(lang))")

        let cards = CardRow([inCard, avgCard, peakCard, durCard], spacing: 7, height: 56)

        let root = vstack([
            SectionTitle(S.thisSession.v(lang), symbol: "bolt.circle"),
            cards,
            SectionTitle(S.chargeCurve.v(lang), symbol: "chart.xyaxis.line"),
            chart,
            weekTitle,
            weekChart,
            hstack([empty, spacer(), exportButton], spacing: 6),
        ], spacing: 7)
        addSubview(root)
        root.pin(to: self, insets: .init(top: 6, left: D.pad, bottom: 8, right: D.pad))
        root.setCustomSpacing(2, after: root.arrangedSubviews[0])
        root.setCustomSpacing(10, after: cards)
        root.setCustomSpacing(2, after: root.arrangedSubviews[2])
        root.setCustomSpacing(10, after: chart)
        root.setCustomSpacing(2, after: weekTitle)
        chart.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        weekChart.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        empty.stringValue = ""
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func exportTapped() {
        switch HistoryStore.shared.exportCSV() {
        case .ok(let url):
            NSWorkspace.shared.activateFileViewerSelecting([url])
            empty.textColor = D.secondary
            empty.stringValue = "→ \(url.lastPathComponent)"
        case .empty:
            empty.textColor = D.secondary
            empty.stringValue = S.noRecord.v(lang)
        case .failed(let why):
            empty.textColor = D.red
            empty.stringValue = "\(S.exportFailed.v(lang))：\(why)"
        }
    }


    override func refresh(power: PowerSnapshot, adapter: AdapterInfo?, stats: SystemStats, energy: [ProcessEnergy]) {
        let session = HistoryStore.shared.currentSession()
        let hasSession = session.seconds > 0
        // 没有记录时统一显示 "—"，不要一半 0 一半 —
        inCard.update(value: hasSession ? String(format: "%.1f Wh", session.wh) : "—")
        avgCard.update(value: hasSession ? String(format: "%.0f W", session.avgW) : "—")
        peakCard.update(value: hasSession ? String(format: "%.0f W", session.peakW) : "—")
        durCard.update(value: hasSession ? fmtDuration(session.seconds) : "—")

        let rows = HistoryStore.shared.recent(minutes: 60).filter { $0.charging }
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        chart.set(downsample(rows.map(\.battery)), labels: downsample(rows.map { df.string(from: $0.ts) }))
        chart.color = rows.isEmpty ? D.tertiary : D.green

        let days = HistoryStore.shared.daily(days: 7)
        let dayF = DateFormatter()
        dayF.dateFormat = "M/d"
        weekChart.set(days.map(\.wh), labels: days.map { dayF.string(from: $0.date) })
        weekTitle.set("\(S.last7.v(lang)) · \(S.dailyWh.v(lang))")
        if exportButton.title != S.exportCSV.v(lang) { exportButton.title = S.exportCSV.v(lang) }
        // 没数据就不让人点，免得点了没反应
        let anyData = days.contains { $0.wh > 0 } || hasSession
        exportButton.isEnabled = anyData
        exportButton.alphaValue = anyData ? 1 : 0.45
    }

    private func downsample(_ a: [Double]) -> [Double] {
        guard a.count > 60 else { return a }
        let step = a.count / 60
        return stride(from: 0, to: a.count, by: step).map { a[$0] }
    }
    private func downsample(_ a: [String]) -> [String] {
        guard a.count > 60 else { return a }
        let step = a.count / 60
        return stride(from: 0, to: a.count, by: step).map { a[$0] }
    }
}

// MARK: - 充电器

final class AdapterPanel: Panel {
    private let bigValue = label("", font: D.rounded(38, .medium), color: D.label)
    private let maxLabel = label("", font: D.text(11), color: D.secondary)
    private let bar = LevelBar()
    private let verdict = label("", font: D.text(11), color: D.label)
    private let vendorRow = KVRow(S.vendor.v(Settings.shared.lang), symbol: "building.2", value: "")
    private let modelRow = KVRow(S.model.v(Settings.shared.lang), symbol: "shippingbox", value: "")
    private let protoRow = KVRow(S.protocolName.v(Settings.shared.lang), symbol: "cable.connector", value: "")
    private let pdoStack = NSStackView()
    private var pdoRows: [KVRow] = []
    private let emptyLabel = label("", font: D.text(11), color: D.tertiary, align: .center)
    private let contentBox = NSView()
    private let emptyHolder = NSView()

    override var preferredHeight: CGFloat { 360 }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.height = 6
        let top = vstack([bigValue, maxLabel, bar], spacing: 3)
        bigValue.translatesAutoresizingMaskIntoConstraints = false
        maxLabel.translatesAutoresizingMaskIntoConstraints = false

        pdoStack.orientation = .vertical
        pdoStack.alignment = .leading
        pdoStack.spacing = 1
        pdoStack.translatesAutoresizingMaskIntoConstraints = false

        contentBox.translatesAutoresizingMaskIntoConstraints = false
        let inner = vstack([
            top,
            SectionTitle(S.healthCheck.v(lang), symbol: "checkmark.seal"),
            verdict,
            SectionTitle(S.pdoTable.v(lang), symbol: "square.stack.3d.up"),
            pdoStack,
            SectionTitle(S.adapter.v(lang), symbol: "magnifyingglass"),
            vendorRow, modelRow, protoRow,
        ], spacing: 6)
        contentBox.addSubview(inner)
        inner.pin(to: contentBox, insets: .init(top: 4, left: 0, bottom: 0, right: 0))

        emptyLabel.translatesAutoresizingMaskIntoConstraints = false
        emptyLabel.maximumNumberOfLines = 3
        emptyLabel.alignment = .center
        emptyLabel.font = D.text(11)
        emptyLabel.textColor = D.tertiary

        let emptyIcon = IconView("powerplug", size: 34, color: D.tertiary)
        let emptyTitle = label(S.noAdapter.v(lang), font: D.text(12, .medium), color: D.secondary, align: .center)
        let emptyStack = vstack([emptyIcon, emptyTitle, emptyLabel], spacing: 7, alignment: .centerX)
        emptyStack.translatesAutoresizingMaskIntoConstraints = false
        emptyHolder.addSubview(emptyStack)
        emptyStack.centerXAnchor.constraint(equalTo: emptyHolder.centerXAnchor).isActive = true
        emptyStack.centerYAnchor.constraint(equalTo: emptyHolder.centerYAnchor).isActive = true
        emptyStack.widthAnchor.constraint(lessThanOrEqualTo: emptyHolder.widthAnchor, constant: -40).isActive = true

        emptyHolder.translatesAutoresizingMaskIntoConstraints = false
        let root = vstack([contentBox, emptyHolder], spacing: 8)
        addSubview(root)
        root.pin(to: self, insets: .init(top: 8, left: D.pad, bottom: 8, right: D.pad))
        emptyHolder.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        emptyHolder.heightAnchor.constraint(greaterThanOrEqualToConstant: 160).isActive = true
        bar.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        verdict.translatesAutoresizingMaskIntoConstraints = false
        verdict.maximumNumberOfLines = 2
        pdoStack.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func refresh(power s: PowerSnapshot, adapter a: AdapterInfo?, stats: SystemStats, energy: [ProcessEnergy]) {
        guard let a, s.isPluggedIn else {
            contentBox.isHidden = true
            emptyHolder.isHidden = false
            emptyLabel.stringValue = S.plugHint.v(lang)
            return
        }
        contentBox.isHidden = false
        emptyHolder.isHidden = true

        bigValue.stringValue = "\(fmtW(a.negotiatedW)) W"
        maxLabel.stringValue = String(format: "%.0fV × %.1fA · %@ %.0f W · %@ %d%%",
                                      a.volts, a.amps,
                                      S.adapterMax.v(lang), a.maxW,
                                      S.utilization.v(lang), Int(a.utilization * 100))
        bar.ratio = CGFloat(a.utilization)
        bar.color = a.utilization > 0.95 ? D.green : (a.utilization > 0.6 ? D.blue : D.orange)

        let v = a.verdict(snap: s)
        verdict.stringValue = v.text
        verdict.textColor = v.level == 0 ? D.secondary : (v.level == 1 ? D.orange : D.red)

        if pdoRows.count != a.pdos.count {
            pdoRows.forEach { $0.removeFromSuperview() }
            pdoRows = a.pdos.map { _ in
                let r = KVRow("", symbol: "bolt.horizontal", value: "")
                pdoStack.addArrangedSubview(r)
                r.widthAnchor.constraint(equalTo: pdoStack.widthAnchor).isActive = true
                return r
            }
        }
        for (i, p) in a.pdos.enumerated() where i < pdoRows.count {
            let active = abs(p.volts - a.volts) < 0.6
            let va = String(format: "%.0fV · %.1fA", p.volts, p.amps)
            pdoRows[i].setKey(active ? "\(S.current.v(lang)) · \(va)" : va)
            pdoRows[i].setKeyColor(active ? D.green : D.secondary)
            pdoRows[i].setValue(String(format: "%.0f W", p.watts),
                                color: active ? D.green : D.secondary)
        }

        vendorRow.setValue(a.name.isEmpty ? S.unknown.v(lang) : a.name)
        modelRow.setValue(a.adapterDescription.isEmpty ? S.unknown.v(lang) : a.adapterDescription)
        protoRow.setValue(a.isWireless ? "Wireless" : String(format: "USB-C PD · %.0fV", a.volts))
    }
}

// MARK: - 设置

final class SettingsPanel: Panel {
    override var needsLiveRefresh: Bool { false }
    private var autostartRow: SwitchRow!
    private var langRow: PopupRow!
    private var menuRow: PopupRow!
    private var intervalRow: PopupRow!
    private var retentionRow: PopupRow!
    private var heatRow: PopupRow!
    private var notifRows: [SwitchRow] = []
    private let aboutLabel = label("", font: D.text(10), color: D.tertiary, align: .center)
    private var updateButton: PillButton!
    private let scrollHeight: CGFloat = 392

    override var preferredHeight: CGFloat { scrollHeight }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false
        let set = Settings.shared
        let l = lang

        autostartRow = SwitchRow(S.autostart.v(l), on: LoginItem.isOn)
        autostartRow.onChange = { on in
            if !LoginItem.set(on) {
                // 失败就把开关拨回去，别骗人
                self.autostartRow.setOn(LoginItem.isOn)
            }
        }

        langRow = PopupRow(S.language.v(l), options: Lang.allCases.map(\.full),
                           selected: Lang.allCases.firstIndex(of: l) ?? 0)
        langRow.onChange = { i in
            set.lang = Lang.allCases[max(0, min(i, 2))]
            NotificationCenter.default.post(name: .ppSettingsChanged, object: nil)
        }

        menuRow = PopupRow(S.menuBarShows.v(l),
                           options: [S.pctAndW.v(l), S.pctOnly.v(l), S.wOnly.v(l), S.iconOnly.v(l)],
                           selected: set.menuBar.rawValue)
        menuRow.onChange = { i in set.menuBar = Settings.MenuBarMode(rawValue: i) ?? .pctAndW }

        let secSuffix = l == .en ? "s" : " 秒"
        intervalRow = PopupRow(S.interval.v(l), options: ["1\(secSuffix)", "2\(secSuffix)", "5\(secSuffix)"],
                               selected: [1.0, 2.0, 5.0].firstIndex(of: set.interval) ?? 0)
        intervalRow.onChange = { i in set.interval = [1.0, 2.0, 5.0][max(0, min(i, 2))] }

        let retentions = [7, 30, 90, 0]
        retentionRow = PopupRow(S.retention.v(l),
                                options: ["7 \(S.days.v(l))", "30 \(S.days.v(l))", "90 \(S.days.v(l))", S.forever.v(l)],
                                selected: retentions.firstIndex(of: set.retentionDays) ?? 1)
        retentionRow.onChange = { i in
            let d = retentions[max(0, min(i, 3))]
            set.retentionDays = d
            HistoryStore.shared.prune(days: d)
        }

        heatRow = PopupRow(S.heatThreshold.v(l), options: ["30 ℃", "35 ℃", "40 ℃"],
                           selected: [30.0, 35.0, 40.0].firstIndex(of: set.heatThreshold) ?? 1)
        heatRow.onChange = { i in set.heatThreshold = [30.0, 35.0, 40.0][max(0, min(i, 2))] }

        let notifSpecs: [(String, Bool, (Bool) -> Void)] = [
            (S.notifyLow.v(l), set.notifyLow, { set.notifyLow = $0 }),
            (S.notifyFull.v(l), set.notifyFull, { set.notifyFull = $0 }),
            (S.notifyUnplug.v(l), set.notifyUnplug, { set.notifyUnplug = $0 }),
            (S.notifyHeat.v(l), set.notifyHeat, { set.notifyHeat = $0 }),
            (S.notifyAnomaly.v(l), set.notifyAnomaly, { set.notifyAnomaly = $0 }),
        ]
        notifRows = notifSpecs.map { spec in
            let r = SwitchRow(spec.0, on: spec.1)
            r.onChange = spec.2
            return r
        }

        // 直接跑裸二进制时没有 Info.plist，别编一个假的 "2.0" 出来
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        aboutLabel.stringValue = version.map { "PowerPulse \($0) · AutumnPants · MIT" } ?? "PowerPulse · AutumnPants · MIT"

        updateButton = PillButton(S.checkUpdate.v(l), target: self, action: #selector(checkUpdate))
        let clearButton = PillButton(S.reset.v(l), target: self, action: #selector(clearHistory))
        let quitButton = PillButton(S.quit.v(l), target: self, action: #selector(quit))

        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false

        // 高温阈值紧跟"高温充电提醒"，逻辑上是一组
        var alertRows: [NSView] = []
        for (i, r) in notifRows.enumerated() {
            alertRows.append(r)
            if i == notifRows.count - 2 { alertRows.append(heatRow) }   // 高温提醒是倒数第二项
        }
        let root = vstack([
            autostartRow,
            langRow, menuRow, intervalRow, retentionRow,
            SectionTitle(l == .en ? "Alerts" : (l == .tw ? "提醒" : "提醒"), symbol: "bell"),
        ] + alertRows, spacing: 2)
        root.setCustomSpacing(10, after: autostartRow)
        root.setCustomSpacing(10, after: retentionRow)
        root.setCustomSpacing(2, after: root.arrangedSubviews.last!)

        let bottom = vstack([sep, hstack([updateButton, spacer(), clearButton, quitButton], spacing: 6), aboutLabel], spacing: 8)
        bottom.setCustomSpacing(6, after: sep)

        let content = vstack([root, bottom], spacing: 12)
        content.alignment = .leading
        // 内容比可视高度长，套一层滚动视图
        let shell = NSView()
        shell.translatesAutoresizingMaskIntoConstraints = false
        shell.addSubview(content)
        content.pin(to: shell, insets: .init(top: 8, left: D.pad, bottom: 10, right: D.pad))
        let sv = wrapScroll(shell, height: 0)
        addSubview(sv)
        sv.pin(to: self, insets: .init(top: 0, left: 0, bottom: 6, right: 0))
        root.widthAnchor.constraint(equalTo: shell.widthAnchor, constant: -D.pad * 2).isActive = true
        bottom.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        notifRows.forEach { $0.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true }
        [autostartRow, langRow, menuRow, intervalRow, retentionRow, heatRow].forEach {
            ($0 as NSView).widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        }
    }
    required init?(coder: NSCoder) { fatalError() }

    @objc private func checkUpdate() {
        updateButton.title = "…"
        UpdateChecker.check { latest in
            if let v = latest {
                self.updateButton.title = "v\(v) →"
                if let url = URL(string: "https://github.com/\(UpdateChecker.repo)/releases/latest") {
                    NSWorkspace.shared.open(url)
                }
            } else {
                self.updateButton.title = S.upToDate.v(Settings.shared.lang)
            }
        }
    }

    @objc private func clearHistory() {
        HistoryStore.shared.clear()
        updateButton.title = S.resetDone.v(Settings.shared.lang)
    }

    @objc private func quit() { NSApp.terminate(nil) }
}

// MARK: - 环形缓冲

final class RingBuffer {
    private var buf: [Double] = []
    private let cap: Int
    var capacity: Int { cap }
    var count: Int { buf.count }
    init(capacity: Int) { cap = capacity }
    func append(_ v: Double) {
        buf.append(v)
        if buf.count > cap { buf.removeFirst(buf.count - cap) }
    }
    var array: [Double] { buf }
}
