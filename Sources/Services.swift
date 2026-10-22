import AppKit
import Foundation
import ServiceManagement
import UserNotifications

// MARK: - 通知

final class Notifier {
    static let shared = Notifier()
    private var authorized = false
    private var low20 = false
    private var low10 = false
    private var fullFired = false
    private var heatFired = false
    private var anomalyFired = false
    private var wasPlugged: Bool?

    func setUp() {
        guard Bundle.main.bundleIdentifier != nil else { return }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] ok, _ in
            self?.authorized = ok
        }
    }

    private func post(_ title: String, _ body: String, id: String) {
        guard authorized else { return }
        let c = UNMutableNotificationContent()
        c.title = title
        c.body = body
        c.sound = .default
        let r = UNNotificationRequest(identifier: id + UUID().uuidString, content: c, trigger: nil)
        UNUserNotificationCenter.current().add(r, withCompletionHandler: nil)
    }

    func evaluate(_ s: PowerSnapshot, adapter: AdapterInfo?, lang: Lang) {
        let set = Settings.shared
        if !s.isPluggedIn {
            low20 = false; low10 = false; fullFired = false; heatFired = false; anomalyFired = false
        }
        if set.notifyLow {
            if s.percent <= 20, !low20, !s.isCharging {
                low20 = true
                post(S.nLowTitle.v(lang), String(format: S.nLowBody.v(lang), s.percent), id: "low")
            }
            if s.percent <= 10, !low10, !s.isCharging {
                low10 = true
                post(S.nCritTitle.v(lang), String(format: S.nCritBody.v(lang), s.percent), id: "crit")
            }
        }
        if set.notifyFull, s.percent >= 100, s.isPluggedIn, !fullFired {
            fullFired = true
            post(S.nFullTitle.v(lang), S.nFullBody.v(lang), id: "full")
        }
        if set.notifyUnplug, let prev = wasPlugged, prev == true, !s.isPluggedIn {
            post(S.nUnplugTitle.v(lang),
                 String(format: S.nUnplugBody.v(lang), fmtClock(s.timeToEmpty)), id: "unplug")
        }
        // 不看是否在充电：电池放热跟充电方向无关，插着电却在补的时候更该提醒
        if set.notifyHeat, s.temperature >= set.heatThreshold, !heatFired {
            heatFired = true
            post(S.nHeatTitle.v(lang), String(format: S.nHeatBody.v(lang), s.temperature), id: "heat")
        }
        if set.notifyAnomaly, s.isCharging, let a = adapter, a.maxW > 0,
           a.negotiatedW < a.maxW * 0.6, s.percent < 80, !anomalyFired, s.slowChargingReason != 0 {
            anomalyFired = true
            post(S.nSlowTitle.v(lang), String(format: S.nSlowBody.v(lang), a.negotiatedW, a.maxW), id: "slow")
        }
        wasPlugged = s.isPluggedIn
    }
}

// MARK: - 开机自启

enum LoginItem {
    static var isOn: Bool { SMAppService.mainApp.status == .enabled }

    @discardableResult
    static func set(_ on: Bool) -> Bool {
        do {
            if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
            Settings.shared.autostart = on
            return true
        } catch {
            Settings.shared.autostart = false
            NSLog("PowerPulse login item: \(error.localizedDescription)")
            return false
        }
    }
}

// MARK: - 更新检查

enum UpdateChecker {
    static let repo = "777cola/PowerPulse"

    static func check(_ done: @escaping (String?) -> Void) {
        guard let url = URL(string: "https://api.github.com/repos/\(repo)/releases/latest") else { return done(nil) }
        var req = URLRequest(url: url)
        req.timeoutInterval = 8
        req.setValue("PowerPulse", forHTTPHeaderField: "User-Agent")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tag = obj["tag_name"] as? String else {
                DispatchQueue.main.async { done(nil) }
                return
            }
            let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
            let latest = tag.replacingOccurrences(of: "v", with: "")
            DispatchQueue.main.async { done(latest.compare(current, options: .numeric) == .orderedDescending ? latest : nil) }
        }.resume()
    }
}

// MARK: - 电源事件（插拔即时响应，不用等下一个采样周期）

final class PowerSourceWatcher {
    private var source: CFRunLoopSource?
    var onChange: (() -> Void)?

    func start() {
        let ctx = Unmanaged.passUnretained(self).toOpaque()
        guard let s = IOPSNotificationCreateRunLoopSource({ context in
            guard let context else { return }
            let watcher = Unmanaged<PowerSourceWatcher>.fromOpaque(context).takeUnretainedValue()
            DispatchQueue.main.async { watcher.onChange?() }
        }, ctx)?.takeRetainedValue() else { return }
        source = s
        CFRunLoopAddSource(CFRunLoopGetMain(), s, .defaultMode)
    }
}
