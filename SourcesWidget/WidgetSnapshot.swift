import Foundation

/// 主 app 与小组件之间共享的快照（JSON，落在 Application Support/PowerPulse/widget.json）
struct WidgetSnapshot: Codable {
    var percent: Int = 0
    var charging = false
    var plugged = false
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
        if charging { return "battery.100.bolt" }
        if percent <= 20 { return "battery.25" }
        if percent <= 50 { return "battery.50" }
        if percent <= 80 { return "battery.75" }
        return "battery.100"
    }

    var stateText: String {
        if charging { return "充电中" }
        if plugged { return percent >= 99 ? "已充满" : "外接电源" }
        return "放电中"
    }
}
