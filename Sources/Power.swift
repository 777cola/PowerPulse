import Foundation
import IOKit
import IOKit.ps
import Darwin

// MARK: - 采样快照

struct PowerSnapshot {
    var wallW: Double = 0          // 墙插输入（SystemPowerIn）
    var systemLoadW: Double = 0    // 系统负载（SystemLoad）
    var batteryW: Double = 0       // 电池功率绝对值
    var adapterLossW: Double = 0
    var isCharging = false
    var isPluggedIn = false
    var percent = 0
    var hasBattery = false          // 台式机（Mac Studio / mini / Pro）没有 AppleSmartBattery
    var currentCapacity = 0        // mAh
    var fullCapacity = 0
    var designCapacity = 0
    var cycleCount = 0
    var temperature: Double = 0    // °C，0 表示读不到
    var timeToEmpty: Int = 0       // 分钟
    var timeToFull: Int = 0
    var slowChargingReason = 0
    var notChargingReason = 0
    var thermallyLimited = 0
    var timestamp = Date()

    var systemUsageW: Double {
        if isPluggedIn { return systemLoadW > 0 ? systemLoadW : max(wallW - batteryW, 0) }
        return batteryW
    }
    var batteryChargeW: Double { isCharging ? batteryW : 0 }
    var batteryDischargeW: Double { isCharging ? 0 : batteryW }
    var healthPercent: Double {
        designCapacity > 0 ? Double(fullCapacity) / Double(designCapacity) * 100 : 0
    }
    var statusTextKey: Tri {
        if isCharging { return S.charging }
        if isPluggedIn { return percent >= 99 ? S.full : S.plugged }
        return S.discharging
    }
}

// MARK: - 充电器

struct AdapterPDO {
    var volts: Double
    var amps: Double
    var watts: Double { volts * amps }
}

struct AdapterInfo {
    var negotiatedW: Double = 0
    var volts: Double = 0
    var amps: Double = 0
    var maxW: Double = 0
    var pdos: [AdapterPDO] = []
    var name: String = ""
    var tier = 0
    var isWireless = false
    var familyCode: UInt32 = 0
    var adapterDescription = ""

    var utilization: Double { maxW > 0 ? min(negotiatedW / maxW, 1) : 0 }

    /// 体检结论：把"为什么没跑满"翻译成人话
    func verdict(snap: PowerSnapshot) -> (text: String, level: Int) {
        // level: 0 正常 1 提示 2 警告
        if isWireless { return (S.wirelessCharging.v(Settings.shared.lang), 1) }
        if snap.thermallyLimited != 0 || snap.temperature >= 42 {
            return (S.vThermal.v(Settings.shared.lang), 2)
        }
        if snap.slowChargingReason != 0 {
            return (S.vSlow.v(Settings.shared.lang), 1)
        }
        if snap.percent >= 95 {
            return (S.vFull.v(Settings.shared.lang), 0)
        }
        if snap.percent >= 80 {
            return (S.vTaper.v(Settings.shared.lang), 0)
        }
        if maxW > 0 && negotiatedW + 0.5 < maxW {
            let lang = Settings.shared.lang
            return (String(format: S.vLimited.v(lang), negotiatedW, maxW), 1)
        }
        return (S.vGood.v(Settings.shared.lang), 0)
    }
}

// MARK: - 系统状态

struct SystemStats {
    var cpu: Double = 0
    var gpu: Double = 0
    var memPercent: Double = 0
    var memUsedGB: Double = 0
    var memTotalGB: Double = 0
    var pressure: Int = 0   // 1 正常 2 警告 4 紧急
}

struct ProcessEnergy: Identifiable {
    let id: Int32
    let name: String
    let milliwatts: Double
}

// MARK: - 采样器

final class Sampler {
    static let shared = Sampler()

    private let queue = DispatchQueue(label: "com.autumnpants.powerpulse.sampler", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var lastCPU: (user: Double, system: Double, nice: Double, idle: Double)?
    private var energyPrev: [Int32: (nj: UInt64, at: Date)] = [:]
    private var energyLive: [ProcessEnergy] = []
    private var lastEnergyAt = Date.distantPast

    var onSample: ((PowerSnapshot, AdapterInfo?) -> Void)?
    var onSystem: ((SystemStats) -> Void)?
    var onEnergy: (([ProcessEnergy]) -> Void)?

    private init() {}

    func start(interval: Double = 1.0) {
        stop()
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now(), repeating: interval, leeway: .milliseconds(120))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// 同步取一次，用于自检 / 截图
    func sampleOnce() -> (PowerSnapshot, AdapterInfo?) { readPower() }
    func systemOnce() -> SystemStats { readSystem() }

    private func tick() {
        let (snap, adapter) = readPower()
        let sys = readSystem()
        // 耗电排行 5 秒一次即可
        if Date().timeIntervalSince(lastEnergyAt) >= 5 {
            lastEnergyAt = Date()
            readEnergy()
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.onSample?(snap, adapter)
            self.onSystem?(sys)
            self.onEnergy?(self.energyLive)
        }
    }

    // MARK: 电源

    private func readPower() -> (PowerSnapshot, AdapterInfo?) {
        var snap = PowerSnapshot()
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return (snap, nil) }
        defer { IOObjectRelease(service) }
        snap.hasBattery = true

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return (snap, nil) }

        let tel = dict["PowerTelemetryData"] as? [String: Any] ?? [:]
        func telMW(_ k: String) -> Double { (tel[k] as? NSNumber).map { $0.doubleValue } ?? 0 }

        snap.wallW = telMW("SystemPowerIn") / 1000
        snap.systemLoadW = telMW("SystemLoad") / 1000
        let raw = (tel["BatteryPower"] as? NSNumber)?.uint64Value ?? 0
        snap.batteryW = abs(Double(Int64(bitPattern: raw))) / 1000
        snap.adapterLossW = telMW("AdapterEfficiencyLoss") / 1000

        snap.isCharging = dict["IsCharging"] as? Bool ?? false
        snap.isPluggedIn = dict["ExternalConnected"] as? Bool ?? false
        snap.percent = (dict["CurrentCapacity"] as? NSNumber)?.intValue ?? 0
        snap.cycleCount = (dict["CycleCount"] as? NSNumber)?.intValue ?? 0
        snap.timeToFull = (dict["AvgTimeToFull"] as? NSNumber)?.intValue ?? 0

        let bd = dict["BatteryData"] as? [String: Any] ?? [:]
        snap.currentCapacity = (bd["AppleRawCurrentCapacity"] as? NSNumber)?.intValue ?? 0
        snap.fullCapacity = (bd["FullChargeCapacity"] as? NSNumber)?.intValue ?? 0
        snap.designCapacity = (bd["DesignCapacity"] as? NSNumber)?.intValue ?? 0
        snap.timeToEmpty = (bd["AvgTimeToEmpty"] as? NSNumber)?.intValue ?? 0
        // 温度在 AppleSmartBatteryPack 的 BatteryData 里（M 系列），不在主节点
        if let t = Self.packTemperature() { snap.temperature = t }

        let cd = dict["ChargerData"] as? [String: Any] ?? [:]
        snap.slowChargingReason = (cd["SlowChargingReason"] as? NSNumber)?.intValue ?? 0
        snap.notChargingReason = (cd["NotChargingReason"] as? NSNumber)?.intValue ?? 0
        snap.thermallyLimited = (cd["TimeChargingThermallyLimited"] as? NSNumber)?.intValue ?? 0

        // 移动平均，避免数字乱跳
        snap.wallW = sm.smooth("wall", snap.wallW)
        snap.systemLoadW = sm.smooth("load", snap.systemLoadW)
        snap.batteryW = sm.smooth("bat", snap.batteryW)

        let adapter = snap.isPluggedIn ? AdapterInfo.parse(dict["AdapterDetails"]) : nil
        return (snap, adapter)
    }

    private let sm = Smoother(window: 8)
    private var lastTemp: Double = 0

    private static func packTemperature() -> Double? {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBatteryPack"))
        guard svc != IO_OBJECT_NULL else { return nil }
        defer { IOObjectRelease(svc) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(svc, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let d = props?.takeRetainedValue() as? [String: Any],
              let bd = d["BatteryData"] as? [String: Any],
              let t = (bd["Temperature"] as? NSNumber)?.doubleValue, t > 0 else { return nil }
        return t / 100
    }

    // MARK: 系统

    private func readSystem() -> SystemStats {
        var st = SystemStats()
        st.cpu = readCPU()
        st.gpu = readGPU()
        let (used, total, pct) = readMemory()
        st.memUsedGB = used
        st.memTotalGB = total
        st.memPercent = pct
        st.pressure = readPressure()
        return st
    }

    private func readCPU() -> Double {
        var count: natural_t = 0
        var info: processor_info_array_t?
        var infoCount: mach_msg_type_number_t = 0
        guard host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &count, &info, &infoCount) == KERN_SUCCESS,
              let info else { return 0 }
        defer {
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info),
                          vm_size_t(Int(infoCount) * MemoryLayout<integer_t>.size))
        }
        var user = 0.0, system = 0.0, nice = 0.0, idle = 0.0
        for i in 0..<Int(count) {
            let o = Int(CPU_STATE_MAX) * i
            user += Double(info[o + Int(CPU_STATE_USER)])
            system += Double(info[o + Int(CPU_STATE_SYSTEM)])
            nice += Double(info[o + Int(CPU_STATE_NICE)])
            idle += Double(info[o + Int(CPU_STATE_IDLE)])
        }
        defer { lastCPU = (user, system, nice, idle) }
        guard let last = lastCPU else { return 0 }
        let dUsed = (user - last.user) + (system - last.system) + (nice - last.nice)
        let dTotal = dUsed + (idle - last.idle)
        guard dTotal > 0 else { return 0 }
        return min(max(dUsed / dTotal * 100, 0), 100)
    }

    private func readGPU() -> Double {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOAccelerator"))
        guard service != IO_OBJECT_NULL else { return 0 }
        defer { IOObjectRelease(service) }
        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return 0 }
        let stats = dict["PerformanceStatistics"] as? [String: Any] ?? [:]
        if let v = (stats["Device Utilization %"] as? NSNumber)?.doubleValue { return v }
        if let v = (stats["GPU Busy"] as? NSNumber)?.doubleValue { return v }
        return 0
    }

    /// 与活动监视器口径一致：App 内存(active 去掉 purgeable) + 联动内存 + 压缩内存。
    /// 旧版把 external_page_count 也加进来，导致虚高，这里不再重复计算。
    private func readMemory() -> (Double, Double, Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        let kr = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        guard kr == KERN_SUCCESS else { return (0, 0, 0) }
        let page = Double(vm_kernel_page_size)
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        let active = Double(stats.active_count) * page
        let wired = Double(stats.wire_count) * page
        let compressed = Double(stats.compressor_page_count) * page
        let purgeable = Double(stats.purgeable_count) * page
        let used = max(active - purgeable, 0) + wired + compressed
        return (used / 1_073_741_824, total / 1_073_741_824, min(used / total * 100, 100))
    }

    private func readPressure() -> Int {
        var level: Int32 = 0
        var size = MemoryLayout<Int32>.size
        if sysctlbyname("kern.memorystatus_vm_pressure_level", &level, &size, nil, 0) == 0 {
            return Int(level)
        }
        return 1
    }

    // MARK: 耗电排行（公开 API：proc_pid_rusage 的能量字段差分）

    private func readEnergy() {
        let now = Date()
        let dt = now.timeIntervalSince(lastEnergyAt == .distantPast ? now : lastEnergyAt)
        guard dt > 0.5 else { return }

        let maxPids = 4096
        var pids = [pid_t](repeating: 0, count: maxPids)
        let bytes = proc_listpids(UInt32(PROC_ALL_PIDS), 0, &pids, Int32(maxPids * MemoryLayout<pid_t>.size))
        let n = Int(bytes) / MemoryLayout<pid_t>.size
        guard n > 1 else { return }

        var next: [Int32: (nj: UInt64, at: Date)] = [:]
        var results: [ProcessEnergy] = []

        for i in 0..<n {
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
            if nj == 0 { continue }
            next[pid] = (nj, now)
            if let prev = energyPrev[pid], nj > prev.nj {
                let mw = Double(nj - prev.nj) / 1_000_000.0 / dt
                if mw >= 1 {
                    results.append(ProcessEnergy(id: pid, name: Self.name(of: pid), milliwatts: mw))
                }
            }
        }
        energyPrev = next
        energyLive = Array(results.sorted { $0.milliwatts > $1.milliwatts }.prefix(6))
    }

    private static func name(of pid: Int32) -> String {
        var buf = [CChar](repeating: 0, count: 256)
        let len = proc_name(pid, &buf, UInt32(buf.count))
        if len > 0 {
            let s = String(cString: buf)
            // 只留可执行文件名，路径太长
            return (s as NSString).lastPathComponent
        }
        return "pid \(pid)"
    }
}

// MARK: - 平滑

final class Smoother {
    private var buckets: [String: [Double]] = [:]
    private let window: Int
    init(window: Int) { self.window = window }
    func smooth(_ key: String, _ v: Double) -> Double {
        var arr = buckets[key] ?? []
        arr.append(v)
        if arr.count > window { arr.removeFirst(arr.count - window) }
        buckets[key] = arr
        return arr.reduce(0, +) / Double(arr.count)
    }
    func reset() { buckets.removeAll() }
}

// MARK: - 适配器解析

extension AdapterInfo {
    static func parse(_ any: Any?) -> AdapterInfo? {
        guard let d = any as? [String: Any] else { return nil }
        let watts = (d["Watts"] as? NSNumber)?.doubleValue ?? 0
        guard watts > 0 || d["UsbHvcMenu"] != nil else { return nil }

        var a = AdapterInfo()
        a.negotiatedW = watts
        a.volts = (d["AdapterVoltage"] as? NSNumber).map { $0.doubleValue / 1000 } ?? 0
        a.amps = (d["Current"] as? NSNumber).map { $0.doubleValue / 1000 } ?? 0
        a.tier = (d["AdapterPowerTier"] as? NSNumber)?.intValue ?? 0
        a.isWireless = d["IsWireless"] as? Bool ?? false
        a.adapterDescription = d["Description"] as? String ?? ""
        if let fc = d["FamilyCode"] as? NSNumber { a.familyCode = UInt32(truncatingIfNeeded: fc.uint64Value) }

        let nameKeys = ["Name", "Model", "Manufacturer"]
        for k in nameKeys {
            if let s = d[k] as? String, !s.isEmpty { a.name = s; break }
        }

        if let menu = d["UsbHvcMenu"] as? [[String: Any]] {
            a.pdos = menu.compactMap { item in
                let v = (item["MaxVoltage"] as? NSNumber).map { $0.doubleValue / 1000 } ?? 0
                let c = (item["MaxCurrent"] as? NSNumber).map { $0.doubleValue / 1000 } ?? 0
                guard v > 0, c > 0 else { return nil }
                return AdapterPDO(volts: v, amps: c)
            }.sorted { $0.volts < $1.volts }
            a.maxW = a.pdos.map(\.watts).max() ?? watts
        } else {
            a.maxW = watts
        }
        return a
    }
}


// MARK: - 自检用假数据（--plugged）

extension PowerSnapshot {
    /// 构造一份"插着 60W 充电器、正在充电"的快照，用来在没插电的机器上检查双带布局
    static func demoPlugged() -> PowerSnapshot {
        var d = PowerSnapshot()
        d.hasBattery = true          // 演示数据是笔记本状态，别让自检掉进台式机分支
        d.isPluggedIn = true
        d.isCharging = true
        d.percent = 87
        d.wallW = 52.3
        d.systemLoadW = 12.8
        d.batteryW = 39.5
        d.currentCapacity = 3738
        d.fullCapacity = 4297
        d.designCapacity = 4629
        d.cycleCount = 176
        d.temperature = 33.2
        d.timeToFull = 38
        d.timeToEmpty = 192
        return d
    }
}

extension AdapterInfo {
    static func demoAdapter() -> AdapterInfo {
        var a = AdapterInfo()
        a.negotiatedW = 52
        a.volts = 20
        a.amps = 2.6
        a.maxW = 60
        a.tier = 2
        a.name = "60W USB-C Power Adapter"
        a.pdos = [5.0, 9.0, 12.0, 15.0, 20.0].map { AdapterPDO(volts: $0, amps: 3.0) }
        return a
    }
}
