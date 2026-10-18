import Foundation
import WidgetKit

/// 把当前状态写给桌面小组件。只在"看得见的变化"时重载 timeline，避免被 WidgetKit 限流。
enum WidgetBridge {
    private static var lastKey = ""
    private static var lastWrite = Date.distantPast

    static func push(_ s: PowerSnapshot, _ a: AdapterInfo?) {
        var w = WidgetSnapshot()
        w.percent = s.percent
        w.charging = s.isCharging
        w.plugged = s.isPluggedIn
        w.wallW = s.wallW
        w.systemW = s.systemUsageW
        w.batteryW = s.batteryW
        w.temp = s.temperature
        w.adapterW = a?.negotiatedW ?? 0
        w.adapterMax = a?.maxW ?? 0
        w.timeToEmpty = s.timeToEmpty > 2000 ? 0 : s.timeToEmpty
        w.timeToFull = s.timeToFull > 2000 ? 0 : s.timeToFull
        w.health = s.healthPercent
        w.updated = s.timestamp
        // 每秒写一次文件没必要：状态没变就 5 秒写一次兜底
        let stateKey = "\(s.percent / 5)|\(s.isCharging)|\(s.isPluggedIn)|\(Int(s.wallW.rounded()))"
        if stateKey != lastKey || Date().timeIntervalSince(lastWrite) >= 5 {
            w.save()
            lastWrite = Date()
        }

        // 电量每 5% 一档，加上插拔/充电状态，够了
        let key = "\(s.percent / 5)|\(s.isCharging)|\(s.isPluggedIn)|\(Int((a?.negotiatedW ?? 0).rounded()))"
        guard key != lastKey else { return }
        lastKey = key
        WidgetCenter.shared.reloadAllTimelines()
    }
}
