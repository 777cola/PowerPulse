import AppKit
import Foundation

// MARK: - 语言

enum Lang: String, CaseIterable {
    case zh, tw, en
    var short: String {
        switch self { case .zh: return "简"; case .tw: return "繁"; case .en: return "EN" }
    }
    var full: String {
        switch self { case .zh: return "简体中文"; case .tw: return "繁體中文"; case .en: return "English" }
    }
    var next: Lang {
        switch self { case .zh: return .tw; case .tw: return .en; case .en: return .zh }
    }
}

/// 三语文案。用结构体而不是字典，缺漏会在编译期暴露。
struct Tri {
    let zh: String, tw: String, en: String
    init(_ zh: String, _ tw: String, _ en: String) { self.zh = zh; self.tw = tw; self.en = en }
    func v(_ l: Lang) -> String {
        switch l { case .zh: return zh; case .tw: return tw; case .en: return en }
    }
}

enum S {
    static let powerFlow = Tri("功率流", "功率流", "Power Flow")
    static let monitor = Tri("系统监控", "系統監控", "System")
    static let history = Tri("充电历史", "充電歷史", "History")
    static let adapter = Tri("充电器", "充電器", "Adapter")
    static let settings = Tri("设置", "設定", "Settings")

    static let wall = Tri("墙插输出", "牆插輸出", "Wall")
    static let systemUse = Tri("系统功耗", "系統功耗", "System")
    static let chargePower = Tri("充电功率", "充電功率", "Charging")
    static let batteryOut = Tri("电池输出", "電池輸出", "Battery")
    static let battery = Tri("电池", "電池", "Battery")

    static let charging = Tri("充电中", "充電中", "Charging")
    static let discharging = Tri("放电中", "放電中", "On battery")
    static let plugged = Tri("外接电源", "外接電源", "Plugged in")
    static let full = Tri("已充满", "已充滿", "Full")
    static let system = Tri("系统", "系統", "Mac")
    static let charge = Tri("充电", "充電", "Charge")
    static let idle = Tri("待机", "待機", "Idle")

    static let remaining = Tri("预计可用", "預計可用", "Time left")
    static let toFull = Tri("预计充满", "預計充滿", "To full")
    static let calculating = Tri("计算中", "計算中", "—")

    static let adapterTitle = Tri("充电器", "充電器", "Charger")
    static let negotiated = Tri("当前协商", "當前協商", "Negotiated")
    static let adapterMax = Tri("套装上限", "套裝上限", "Kit max")
    static let utilization = Tri("功率利用", "功率利用", "Utilization")
    static let gear = Tri("档位", "檔位", "gear")
    static let draw = Tri("取电", "取電", "drawing")
    static let pdoTable = Tri("PD 档位", "PD 檔位", "PDO table")
    static let vendor = Tri("厂商", "廠商", "Vendor")
    static let model = Tri("型号", "型號", "Model")
    static let protocolName = Tri("协议", "協議", "Protocol")
    static let noAdapter = Tri("未检测到充电器", "未偵測到充電器", "No charger detected")
    static let plugHint = Tri("插上充电器，这里会显示这套充电套装能跑多快", "插上充電器，這裡會顯示這套充電套裝能跑多快", "Plug in to see what your charging kit can do")
    static let wirelessCharging = Tri("无线充电，功率不可控", "無線充電，功率不可控", "Wireless charging")
    static let vThermal = Tri("电池温度偏高，系统已在降功率保护", "電池溫度偏高，系統已在降功率保護", "Charging limited by battery temperature")
    static let vSlow = Tri("充电速度受限，可能是线材或充电头档位不够", "充電速度受限，可能是線材或充電頭檔位不夠", "Charging speed limited — cable or adapter tier")
    static let vTaper = Tri("电量已进入涓流阶段，降功率是正常的", "電量已進入涓流階段，降功率是正常的", "Tapering near full — normal")
    static let vFull = Tri("接近充满，功率自然降低", "接近充滿，功率自然降低", "Nearly full — power tapers off")
    static let vGood = Tri("满功率协商，充电套装一切正常", "滿功率協商，充電套裝一切正常", "Negotiated at full power — kit is fine")
    static let vLimited = Tri("当前协商 %@W，低于套装上限 %@W", "當前協商 %@W，低於套裝上限 %@W", "Negotiated %@W, below kit max %@W")
    static let unknown = Tri("未上报", "未上報", "not reported")
    static let healthCheck = Tri("体检结论", "體檢結論", "Verdict")
    static let wattsOfMax = Tri("上限", "上限", "max")

    static let health = Tri("电池健康", "電池健康", "Health")
    static let cycles = Tri("循环次数", "循環次數", "Cycles")
    static let designCap = Tri("设计容量", "設計容量", "Design")
    static let actualCap = Tri("实际容量", "實際容量", "Actual")
    static let temperature = Tri("温度", "溫度", "Temp.")
    static let age = Tri("电池年龄", "電池年齡", "Age")
    static let normal = Tri("正常", "正常", "Normal")
    static let warm = Tri("偏热", "偏熱", "Warm")
    static let hot = Tri("过热", "過熱", "Hot")

    static let cpu = Tri("CPU", "CPU", "CPU")
    static let mem = Tri("内存", "記憶體", "Memory")
    static let energyTitle = Tri("耗电排行", "耗電排行", "Energy use")
    static let cpuLoad = Tri("负载", "負載", "Load")
    static let powerCurve = Tri("系统功耗曲线", "系統功耗曲線", "System power")
    static let energyHint = Tri("仅统计当前用户可见的进程", "僅統計當前使用者可見的程序", "Current-user processes only")

    static let thisSession = Tri("本次充电", "本次充電", "This session")
    static let totalIn = Tri("累计充入", "累計充入", "Energy in")
    static let avgPower = Tri("平均功率", "平均功率", "Avg power")
    static let peakPower = Tri("峰值功率", "峰值功率", "Peak")
    static let duration = Tri("时长", "時長", "Duration")
    static let last7 = Tri("近 7 天", "近 7 天", "Last 7 days")
    static let noRecord = Tri("暂无记录", "暫無記錄", "No data yet")
    static let exportCSV = Tri("导出 CSV", "匯出 CSV", "Export CSV")
    static let exported = Tri("已导出", "已匯出", "Exported")
    static let dailyWh = Tri("每天充入", "每天充入", "Daily Wh")

    static let autostart = Tri("开机自启", "開機自啟", "Launch at login")
    static let language = Tri("语言", "語言", "Language")
    static let interval = Tri("采样间隔", "取樣間隔", "Sample rate")
    static let retention = Tri("历史保留", "歷史保留", "Keep history")
    static let menuBarShows = Tri("菜单栏显示", "選單列顯示", "Menu bar")
    static let notifyLow = Tri("低电量提醒", "低電量提醒", "Low battery alert")
    static let notifyFull = Tri("充满提醒", "充滿提醒", "Full charge alert")
    static let notifyUnplug = Tri("拔电提醒", "拔電提醒", "Unplug alert")
    static let notifyHeat = Tri("高温充电提醒", "高溫充電提醒", "Hot charging alert")
    static let notifyAnomaly = Tri("充电异常提醒", "充電異常提醒", "Charging anomaly")
    static let heatThreshold = Tri("高温阈值", "高溫閾值", "Heat threshold")
    static let forever = Tri("永久", "永久", "Forever")
    static let days = Tri("天", "天", "days")
    static let second = Tri("秒", "秒", "s")
    static let about = Tri("关于", "關於", "About")
    static let checkUpdate = Tri("检查更新", "檢查更新", "Updates")
    static let upToDate = Tri("已是最新", "已是最新", "Up to date")
    static let newVersion = Tri("有新版本", "有新版本", "Update available")
    static let quit = Tri("退出", "結束", "Quit")
    static let reset = Tri("清空历史", "清空歷史", "Clear")
    static let resetDone = Tri("已清空", "已清空", "Cleared")
    static let on = Tri("开", "開", "On")
    static let off = Tri("关", "關", "Off")

    static let pctAndW = Tri("百分比 + 功率", "百分比 + 功率", "Percent + watts")
    static let pctOnly = Tri("仅百分比", "僅百分比", "Percent only")
    static let wOnly = Tri("仅功率", "僅功率", "Watts only")
    static let iconOnly = Tri("仅图标", "僅圖示", "Icon only")
}

// MARK: - 设计常量

enum D {
    static let width: CGFloat = 320
    static let pad: CGFloat = 16
    static let radius: CGFloat = 10
    static let blue = NSColor.systemBlue
    static let green = NSColor.systemGreen
    static let orange = NSColor.systemOrange
    static let red = NSColor.systemRed
    static let purple = NSColor.systemPurple
    static let label = NSColor.labelColor
    static let secondary = NSColor.secondaryLabelColor
    static let tertiary = NSColor.tertiaryLabelColor

    static func num(_ size: CGFloat, _ weight: NSFont.Weight = .semibold) -> NSFont {
        let base = NSFont.monospacedDigitSystemFont(ofSize: size, weight: weight)
        return base
    }
    static func rounded(_ size: CGFloat, _ weight: NSFont.Weight = .bold) -> NSFont {
        let f = NSFont.systemFont(ofSize: size, weight: weight)
        if let d = f.fontDescriptor.withDesign(.rounded) { return NSFont(descriptor: d, size: size) ?? f }
        return f
    }
    static func text(_ size: CGFloat, _ weight: NSFont.Weight = .regular) -> NSFont {
        NSFont.systemFont(ofSize: size, weight: weight)
    }
    static var cardFill: NSColor { NSColor.labelColor.withAlphaComponent(0.055) }
    static var cardLine: NSColor { NSColor.labelColor.withAlphaComponent(0.06) }
    static var trackFill: NSColor { NSColor.labelColor.withAlphaComponent(0.09) }
}

// MARK: - 设置

final class Settings {
    static let shared = Settings()
    private let d = UserDefaults.standard

    private enum K: String {
        case lang, interval, retention, menuBar, notifyLow, notifyFull, notifyUnplug,
             notifyHeat, notifyAnomaly, heatThreshold, autostart, onboarded
    }

    var lang: Lang {
        get { Lang(rawValue: d.string(forKey: K.lang.rawValue) ?? "zh") ?? .zh }
        set {
            d.set(newValue.rawValue, forKey: K.lang.rawValue)
            NotificationCenter.default.post(name: .ppSettingsChanged, object: nil)
        }
    }
    var interval: Double {
        get { let v = d.double(forKey: K.interval.rawValue); return v > 0 ? v : 1.0 }
        set { d.set(newValue, forKey: K.interval.rawValue) }
    }
    var retentionDays: Int {
        get { d.object(forKey: K.retention.rawValue) as? Int ?? 30 }
        set { d.set(newValue, forKey: K.retention.rawValue) }
    }
    enum MenuBarMode: Int { case pctAndW = 0, pctOnly = 1, wOnly = 2, iconOnly = 3 }
    var menuBar: MenuBarMode {
        get { MenuBarMode(rawValue: d.integer(forKey: K.menuBar.rawValue)) ?? .pctAndW }
        set {
            d.set(newValue.rawValue, forKey: K.menuBar.rawValue)
            NotificationCenter.default.post(name: .ppSettingsChanged, object: nil)
        }
    }
    var notifyLow: Bool { get { d.object(forKey: K.notifyLow.rawValue) as? Bool ?? true } set { d.set(newValue, forKey: K.notifyLow.rawValue) } }
    var notifyFull: Bool { get { d.object(forKey: K.notifyFull.rawValue) as? Bool ?? true } set { d.set(newValue, forKey: K.notifyFull.rawValue) } }
    var notifyUnplug: Bool { get { d.object(forKey: K.notifyUnplug.rawValue) as? Bool ?? false } set { d.set(newValue, forKey: K.notifyUnplug.rawValue) } }
    var notifyHeat: Bool { get { d.object(forKey: K.notifyHeat.rawValue) as? Bool ?? true } set { d.set(newValue, forKey: K.notifyHeat.rawValue) } }
    var notifyAnomaly: Bool { get { d.object(forKey: K.notifyAnomaly.rawValue) as? Bool ?? true } set { d.set(newValue, forKey: K.notifyAnomaly.rawValue) } }
    var heatThreshold: Double { get { let v = d.double(forKey: K.heatThreshold.rawValue); return v > 0 ? v : 35 } set { d.set(newValue, forKey: K.heatThreshold.rawValue) } }
    var autostart: Bool { get { d.bool(forKey: K.autostart.rawValue) } set { d.set(newValue, forKey: K.autostart.rawValue) } }
    var onboarded: Bool { get { d.bool(forKey: K.onboarded.rawValue) } set { d.set(newValue, forKey: K.onboarded.rawValue) } }

    func text(_ t: Tri) -> String { t.v(lang) }
}

extension Notification.Name {
    static let ppSettingsChanged = Notification.Name("pp.settings")
    static let ppTick = Notification.Name("pp.tick")
    static let ppAdapterChanged = Notification.Name("pp.adapter")
}

// MARK: - 小工具

extension NSColor {
    convenience init(hex: UInt32) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                  green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

extension String {
    func size(_ font: NSFont) -> NSSize {
        (self as NSString).size(withAttributes: [.font: font])
    }
}

func fmtW(_ v: Double, decimals: Int = 0) -> String {
    decimals == 0 ? String(format: "%.0f", v) : String(format: "%.\(decimals)f", v)
}

func fmtDuration(_ seconds: Double) -> String {
    let m = Int(seconds / 60)
    if m <= 0 { return "<1 min" }
    if m < 60 { return "\(m) min" }
    return "\(m / 60)h \(m % 60)m"
}

func fmtClock(_ minutes: Int) -> String {
    if minutes <= 0 { return "—" }
    if minutes < 60 { return "\(minutes) min" }
    return "\(minutes / 60):" + String(format: "%02d", minutes % 60)
}

extension NSView {
    func pin(to other: NSView, insets: NSEdgeInsets = .init()) {
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: other.leadingAnchor, constant: insets.left),
            trailingAnchor.constraint(equalTo: other.trailingAnchor, constant: -insets.right),
            topAnchor.constraint(equalTo: other.topAnchor, constant: insets.top),
            bottomAnchor.constraint(equalTo: other.bottomAnchor, constant: -insets.bottom),
        ])
    }
}

func label(_ text: String, font: NSFont, color: NSColor = D.label, align: NSTextAlignment = .left) -> NSTextField {
    let l = NSTextField(labelWithString: text)
    l.font = font
    l.textColor = color
    l.alignment = align
    l.maximumNumberOfLines = 1
    l.lineBreakMode = .byTruncatingTail
    return l
}
