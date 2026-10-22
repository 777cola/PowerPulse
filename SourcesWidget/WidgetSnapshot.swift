import Foundation

/// 主 app 与小组件之间共享的快照（JSON，落在 Application Support/PowerPulse/widget.json）
struct WidgetSnapshot: Codable {
    var percent: Int = 0
    var hasBattery = true          // 台式机 false：小组件不能写 0%
    var charging = false
    var plugged = false
    var draining = false           // 插着电但电池在放电（充电器不够）
    var lang = "zh"                // 主 app 的语言，小组件跟着切
    var wallW: Double = 0
    var systemW: Double = 0
    var batteryW: Double = 0
    var temp: Double = 0
    var adapterW: Double = 0
    var adapterMax: Double = 0
    var timeToEmpty = 0
    var timeToFull = 0
    var health: Double = 0
    var updated = Date()

    /// 自己解：合成解码器碰到缺字段会整份失败（旧版 widget.json 没有 draining/lang），
    /// 那样小组件会直接掉到 0%。缺什么就用默认值顶上。
    init() {}

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        percent = try c.decodeIfPresent(Int.self, forKey: .percent) ?? 0
        hasBattery = try c.decodeIfPresent(Bool.self, forKey: .hasBattery) ?? true
        charging = try c.decodeIfPresent(Bool.self, forKey: .charging) ?? false
        plugged = try c.decodeIfPresent(Bool.self, forKey: .plugged) ?? false
        draining = try c.decodeIfPresent(Bool.self, forKey: .draining) ?? false
        lang = try c.decodeIfPresent(String.self, forKey: .lang) ?? "zh"
        wallW = try c.decodeIfPresent(Double.self, forKey: .wallW) ?? 0
        systemW = try c.decodeIfPresent(Double.self, forKey: .systemW) ?? 0
        batteryW = try c.decodeIfPresent(Double.self, forKey: .batteryW) ?? 0
        temp = try c.decodeIfPresent(Double.self, forKey: .temp) ?? 0
        adapterW = try c.decodeIfPresent(Double.self, forKey: .adapterW) ?? 0
        adapterMax = try c.decodeIfPresent(Double.self, forKey: .adapterMax) ?? 0
        timeToEmpty = try c.decodeIfPresent(Int.self, forKey: .timeToEmpty) ?? 0
        timeToFull = try c.decodeIfPresent(Int.self, forKey: .timeToFull) ?? 0
        health = try c.decodeIfPresent(Double.self, forKey: .health) ?? 0
        updated = try c.decodeIfPresent(Date.self, forKey: .updated) ?? Date.distantPast
    }

    static let empty = WidgetSnapshot()

    static let widgetBundleID = "com.autumnpants.powerpulse.widget"

    /// 小组件被沙盒围住，只能读自己的容器。主 app 没沙盒，可以直接往这个目录里写。
    static var fileURL: URL {
        let sandbox = URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Containers/\(widgetBundleID)/Data/Library/Application Support/PowerPulse", isDirectory: true)
        if FileManager.default.fileExists(atPath: sandbox.path) || !isSandboxed {
            try? FileManager.default.createDirectory(at: sandbox, withIntermediateDirectories: true)
            return sandbox.appendingPathComponent("widget.json")
        }
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory() + "/Library/Application Support")
        let dir = base.appendingPathComponent("PowerPulse", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("widget.json")
    }

    /// 沙盒里的进程 environment 会带 APP_SANDBOX_CONTAINER_ID
    static var isSandboxed: Bool { ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil }

    /// 依次尝试几个可能的位置，取最新的那份（沙盒内外的 Application Support 不是同一个目录）
    static func load() -> WidgetSnapshot {
        var candidates: [URL] = [fileURL]
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("PowerPulse/widget.json")
        if let appSupport { candidates.append(appSupport) }
        candidates.append(URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support/PowerPulse/widget.json"))

        let dec = JSONDecoder()
        dec.dateDecodingStrategy = .secondsSince1970
        var best: (Date, WidgetSnapshot)?
        for url in candidates {
            guard let data = try? Data(contentsOf: url),
                  let snap = try? dec.decode(WidgetSnapshot.self, from: data) else { continue }
            if best == nil || snap.updated > best!.0 { best = (snap.updated, snap) }
        }
        return best?.1 ?? .empty
    }

    func save() {
        let enc = JSONEncoder()
        enc.dateEncodingStrategy = .secondsSince1970
        if let data = try? enc.encode(self) {
            try? data.write(to: Self.fileURL, options: .atomic)
        }
    }

    // 徽标/文案
    var symbolName: String {
        if !hasBattery { return "powerplug.fill" }
        if charging { return "battery.100.bolt" }
        if percent <= 20 { return "battery.25" }
        if percent <= 50 { return "battery.50" }
        if percent <= 80 { return "battery.75" }
        return "battery.100"
    }

    var stateText: String {
        if !hasBattery { return text.directPower }
        if charging { return text.charging }
        if plugged && draining { return text.assisting }
        if plugged { return percent >= 99 ? text.full : text.pluggedIn }
        return text.discharging
    }

    var text: WText { WText(lang: lang) }
}


// MARK: - 小组件文案（三语）

/// 小组件跑在沙盒里，读不到主 app 的 UserDefaults，
/// 所以语言由主 app 塞进快照跟着一起写过来。
struct WText {
    let lang: String
    private func t(_ zh: String, _ tw: String, _ en: String) -> String {
        switch lang {
        case "en": return en
        case "tw": return tw
        default: return zh
        }
    }

    var charging: String { t("充电中", "充電中", "Charging") }
    var full: String { t("已充满", "已充滿", "Full") }
    var pluggedIn: String { t("外接电源", "外接電源", "Plugged in") }
    var discharging: String { t("放电中", "放電中", "On battery") }
    var directPower: String { t("插电直供", "插電直供", "Direct power") }
    var assisting: String { t("电池补充", "電池補充", "Assisting") }
    var noBattery: String { t("插电直供 · 无电池", "插電直供 · 無電池", "Direct power · no battery") }

    func gear(_ now: Int, _ max: Int) -> String {
        t("档位 \(now)/\(max)", "檔位 \(now)/\(max)", "gear \(now)/\(max)")
    }
    func kitMax(_ w: Int) -> String { t("套装上限 \(w)W", "套裝上限 \(w)W", "kit max \(w)W") }
    func health(_ h: String) -> String { t("电池健康 \(h)%", "電池健康 \(h)%", "Health \(h)%") }
    func wall(_ w: Int) -> String { t("墙插 \(w) W", "牆插 \(w) W", "Wall \(w) W") }
    func system(_ w: Int) -> String { t("系统 \(w) W", "系統 \(w) W", "System \(w) W") }
    func into(_ w: String, _ rest: String) -> String {
        t("电池 \(w) W 充入 · \(rest)", "電池 \(w) W 充入 · \(rest)", "Battery +\(w) W · \(rest)")
    }
    func out(_ w: String, _ rest: String) -> String {
        t("电池放电 \(w) W · \(rest)", "電池放電 \(w) W · \(rest)", "Battery −\(w) W · \(rest)")
    }
    /// 剩余时间：0 = 算不出来
    func rest(_ minutes: Int) -> String {
        guard minutes > 0, minutes < 1440 else { return "—" }
        let h = minutes / 60
        if h == 0 { return t("\(minutes) 分钟", "\(minutes) 分鐘", "\(minutes)m") }
        let m = String(format: "%02d", minutes % 60)
        return t("剩 \(h):\(m)", "剩 \(h):\(m)", "\(h)h \(m)m left")
    }
    func toFull(_ minutes: Int) -> String {
        guard minutes > 0, minutes < 1440 else { return "—" }
        let h = minutes / 60
        if h == 0 { return t("\(minutes) 分钟充满", "\(minutes) 分鐘充滿", "\(minutes)m to full") }
        let m = String(format: "%02d", minutes % 60)
        return t("\(h):\(m) 充满", "\(h):\(m) 充滿", "\(h)h \(m)m to full")
    }
}
