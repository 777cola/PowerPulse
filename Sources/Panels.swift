import AppKit

// MARK: - 面板基类

class Panel: NSView {
    var preferredHeight: CGFloat { 300 }
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
    private let wallCard = MetricCard(title: S.wall.v(Settings.shared.lang), symbol: "powerplug.fill", color: D.label)
    private let sysCard = MetricCard(title: S.systemUse.v(Settings.shared.lang), symbol: "desktopcomputer", color: D.blue)
    private let batCard = MetricCard(title: S.batteryOut.v(Settings.shared.lang), symbol: "battery.25", color: D.orange)
    private let stateCard = MetricCard(title: S.battery.v(Settings.shared.lang), symbol: "bolt.fill", color: D.green)

    private let adapterLine = label("", font: D.text(10), color: D.secondary)
    private let adapterValue = label("", font: D.num(10, .medium), color: D.label, align: .right)
    private let bar = LevelBar()
    private let adapterBox = NSView()

    override var preferredHeight: CGFloat { 292 }

    init() {
        super.init(frame: .zero)
        translatesAutoresizingMaskIntoConstraints = false

        flow.translatesAutoresizingMaskIntoConstraints = false
        flow.heightAnchor.constraint(equalToConstant: 160).isActive = true

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

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil { flow.startAnimating() } else { flow.stopAnimating() }
    }

    override func refresh(power s: PowerSnapshot, adapter a: AdapterInfo?, stats: SystemStats, energy: [ProcessEnergy]) {
        flow.update(s, a)
        wallCard.update(value: s.isPluggedIn ? "\(fmtW(s.wallW)) W" : "—")
        sysCard.update(value: "\(fmtW(s.systemUsageW)) W")

        if s.isCharging {
            batCard.update(title: S.chargePower.v(lang), value: String(format: "%.1f W", s.batteryChargeW), valueColor: D.green)
        } else {
            batCard.update(title: s.isPluggedIn ? S.batteryOut.v(lang) : S.batteryOut.v(lang),
                           value: String(format: "%.1f W", s.batteryDischargeW), valueColor: D.orange)
        }
        stateCard.update(title: "\(S.battery.v(lang)) \(s.percent)%",
                         value: s.statusTextKey.v(lang),
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
    private let energyStack = NSStackView()
    private var energyRows: [KVRow] = []
    private let liveBuffer = RingBuffer(capacity: 90)

    override var preferredHeight: CGFloat { 376 }

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
            SectionTitle(S.powerCurve.v(lang), symbol: "waveform.path.ecg"),
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
        cpuRow.setValue(String(format: "%.0f%%", stats.cpu))
        gpuRow.setValue(String(format: "%.0f%%", stats.gpu))
        memRow.setValue(String(format: "%.1f / %.0f GB", stats.memUsedGB, stats.memTotalGB))
        cpuBar.ratio = CGFloat(stats.cpu / 100)
        gpuBar.ratio = CGFloat(stats.gpu / 100)
        memBar.ratio = CGFloat(stats.memPercent / 100)

        liveBuffer.append(power.systemUsageW)
        chart.set(liveBuffer.array)

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
            SectionTitle(S.powerFlow.v(lang), symbol: "chart.xyaxis.line"),
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
        if let url = HistoryStore.shared.exportCSV() {
            NSWorkspace.shared.activateFileViewerSelecting([url])
            empty.stringValue = "→ \(url.lastPathComponent)"
        } else {
            empty.stringValue = S.noRecord.v(lang)
        }
    }

    override func refresh(power: PowerSnapshot, adapter: AdapterInfo?, stats: SystemStats, energy: [ProcessEnergy]) {
        let session = HistoryStore.shared.currentSession()
        inCard.update(value: String(format: "%.1f Wh", session.wh))
        avgCard.update(value: String(format: "%.0f W", session.avgW))
        peakCard.update(value: String(format: "%.0f W", session.peakW))
        durCard.update(value: session.seconds > 0 ? fmtDuration(session.seconds) : "—")

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
        exportButton.title = S.exportCSV.v(lang)
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

        let root = vstack([contentBox, emptyLabel], spacing: 8)
        addSubview(root)
        root.pin(to: self, insets: .init(top: 8, left: D.pad, bottom: 8, right: D.pad))
        bar.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
        verdict.translatesAutoresizingMaskIntoConstraints = false
        verdict.maximumNumberOfLines = 2
        pdoStack.widthAnchor.constraint(equalTo: root.widthAnchor).isActive = true
    }
    required init?(coder: NSCoder) { fatalError() }

    override func refresh(power s: PowerSnapshot, adapter a: AdapterInfo?, stats: SystemStats, energy: [ProcessEnergy]) {
        guard let a, s.isPluggedIn else {
            contentBox.isHidden = true
            emptyLabel.isHidden = false
            emptyLabel.stringValue = "\(S.noAdapter.v(lang))\n\(S.plugHint.v(lang))"
            return
        }
        contentBox.isHidden = false
        emptyLabel.isHidden = true

        bigValue.stringValue = "\(fmtW(a.negotiatedW)) W"
        maxLabel.stringValue = "\(S.negotiated.v(lang)) · \(S.adapterMax.v(lang)) \(fmtW(a.maxW)) W · \(S.utilization.v(lang)) \(Int(a.utilization * 100))%"
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
            pdoRows[i].setKey(String(format: "%.0fV · %.1fA", p.volts, p.amps))
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

        intervalRow = PopupRow(S.interval.v(l), options: ["1 s", "2 s", "5 s"],
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

        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "2.0"
        aboutLabel.stringValue = "PowerPulse \(version) · AutumnPants · MIT"

        updateButton = PillButton(S.checkUpdate.v(l), target: self, action: #selector(checkUpdate))
        let clearButton = PillButton(S.reset.v(l), target: self, action: #selector(clearHistory))
        let quitButton = PillButton(S.quit.v(l), target: self, action: #selector(quit))

        let sep = NSBox()
        sep.boxType = .separator
        sep.translatesAutoresizingMaskIntoConstraints = false

        let root = vstack([
            autostartRow,
            langRow, menuRow, intervalRow, retentionRow,
            SectionTitle(S.energyTitle.v(l).isEmpty ? "" : (l == .en ? "Alerts" : "提醒"), symbol: "bell"),
        ] + notifRows + [
            heatRow,
        ], spacing: 2)
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
    init(capacity: Int) { cap = capacity }
    func append(_ v: Double) {
        buf.append(v)
        if buf.count > cap { buf.removeFirst(buf.count - cap) }
    }
    var array: [Double] { buf }
}
