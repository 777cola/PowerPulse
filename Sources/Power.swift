import Foundation
import IOKit
import IOKit.ps
import Darwin

// MARK: - 采样快照

struct PowerSnapshot {
    var wallW: Double = 0          // 墙插输入（SystemPowerIn）
    var systemLoadW: Double = 0    // 系统负载（SystemLoad）
    var batteryW: Double = 0       // 电池功率绝对值
    var batteryDraining = false     // BatteryPower 为负：电池在放电
    var adapterLossW: Double = 0
    var isCharging = false
    var isPluggedIn = false
    var percent = 0
    var hasBattery = false          // 台式机（Mac Studio / mini / Pro）没有 AppleSmartBattery
    var desktopW: Double = 0        // 台式机整机功率（SMC PSTR/PDTR），0 = 读不到
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


    /// 系统功耗。直接信 PSTR（实测随负载 6W→23W，整机口径），
    /// 墙插反过来由它推出（wall = 系统 + 电池），所以三个数永远自洽。
    /// 早先用「墙插 − 电池」的残差当系统：电池的 SBS 每 30 秒才更新一次、
    /// 一跳 10W，残差就跟着跳 10W，看着像数据源坏了。
    var systemUsageW: Double {
        if systemLoadW > 0.2 { return systemLoadW }
        if hasBattery { return batteryW }      // PSTR 读不到：放电时电池就是系统
        return 0
    }
    var batteryChargeW: Double { isCharging ? batteryW : 0 }
    var batteryDischargeW: Double { isCharging ? 0 : batteryW }
    var healthPercent: Double {
        designCapacity > 0 ? Double(fullCapacity) / Double(designCapacity) * 100 : 0
    }
    /// 电从哪来、到哪去
    var flowMode: FlowMode {
        if !isPluggedIn { return .discharging }
        if isCharging && !batteryDraining { return .charging }
        if batteryDraining && batteryW > 0.3 { return .supplementing }
        return .charging          // 插着但静置（电量满、没有净流入）
    }
    var statusTextKey: Tri {
        // 100% 还在涓流：macOS 会报 IsCharging=1，但它已经满了
        if isCharging && percent >= 100 && batteryW < 1 { return S.full }
        if isCharging { return S.charging }
        if flowMode == .supplementing { return S.supplementShort }
        if isPluggedIn { return percent >= 99 ? S.full : S.plugged }
        return S.discharging
    }
}

/// 三种能量流向：充电器喂系统和电池 / 充电器和电池一起喂系统 / 只有电池
enum FlowMode { case charging, supplementing, discharging }

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
        // 插着电却还在放电：结论只能是"充电器带不动"，不是"快充满了"
        if snap.flowMode == .supplementing {
            // 用电池实际出力，别用"系统 - 墙插"倒算：两者差 0.1 就对不上图里的数字
            let missing = max(snap.batteryW, 0)
            return (String(format: S.vShort.v(Settings.shared.lang), missing), 2)
        }
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
        guard service != IO_OBJECT_NULL else {
            // 台式机：没有电池，瓦数只能问 SMC。读不到就留 0，界面显示 —
            snap.hasBattery = false
            if let w = SMCPower.systemWatts() {
                snap.desktopW = w
                // 台式机没有电池，整机吃多少墙插就出多少：两条数都填上，
                // 功率流/历史/小组件才能和笔记本走同一套
                snap.wallW = w
                snap.systemLoadW = w
            }
            return (snap, nil)
        }
        defer { IOObjectRelease(service) }
        snap.hasBattery = true

        var props: Unmanaged<CFMutableDictionary>?
        guard IORegistryEntryCreateCFProperties(service, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
              let dict = props?.takeRetainedValue() as? [String: Any] else { return (snap, nil) }

        let tel = dict["PowerTelemetryData"] as? [String: Any] ?? [:]
        func telMW(_ k: String) -> Double { (tel[k] as? NSNumber).map { $0.doubleValue } ?? 0 }

        // PowerTelemetryData 会整块停更：插着 60W 快充时它仍报 SystemPowerIn=0、
        // SystemLoad=0.6W，而电池其实在吃 44W。所以各个数都换成能自洽的来源：
        //   电池 = 顶层 BatteryPower（正充负放）→ Amperage×Voltage → 遥测
        //   系统 = SMC PSTR → 遥测 SystemLoad
        //   墙插 = SMC PDTR → 遥测 SystemPowerIn → 系统 ± 电池
        let amp = (dict["Amperage"] as? NSNumber)?.doubleValue ?? 0
        let volt = (dict["Voltage"] as? NSNumber)?.doubleValue ?? 0
        let battTopW = (dict["BatteryPower"] as? NSNumber).map { $0.doubleValue / 1000 }
        let battAmpW: Double? = (amp != 0 && volt != 0) ? amp * volt / 1_000_000 : nil
        // 遥测这块可能整块停更、也可能溢出（uint64 回绕成 1.8e16），所以放最后一级
        let telRaw = (tel["BatteryPower"] as? NSNumber)?.uint64Value
        let battTelW = telRaw.map { Double(Int64(bitPattern: $0)) / 1000 }
        let signedBatW = PowerMath.pickBattery(top: battTopW, ampereVolt: battAmpW, telemetry: battTelW) ?? 0

        let state = PowerMath.chargeState(signedBatteryW: signedBatW,
                                          flag: dict["IsCharging"] as? Bool ?? false)
        snap.isCharging = state.charging
        snap.batteryDraining = state.draining
        snap.batteryW = abs(signedBatW)
        snap.adapterLossW = telMW("AdapterEfficiencyLoss") / 1000
        snap.isPluggedIn = dict["ExternalConnected"] as? Bool ?? false

        // 系统功耗：PSTR（实测随 CPU 负载 6W→23W，是整机口径）。
        // 它偶发报 -4.3W / 瞬时尖峰，读不到就沿用上一次的好值，别退回慢半拍的遥测
        if let p = PowerMath.sanePositive(SMCPower.read("PSTR")?.value) { lastSystemW = p }
        let telLoad = PowerMath.sanePositive(telMW("SystemLoad") / 1000)
        snap.systemLoadW = lastSystemW ?? telLoad ?? 0
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

        // 平滑：系统跟负载要快（0.55），电池的 SBS 30 秒才更新一次、一跳 10W，
        // 慢了才能在界面上走成斜坡而不是台阶
        if !snap.isPluggedIn || lastPlugged != snap.isPluggedIn { sm.reset() }
        lastPlugged = snap.isPluggedIn
        snap.systemLoadW = sm.smooth("sys", snap.systemLoadW)
        snap.batteryW = sm.smooth("bat", snap.batteryW, alpha: 0.3)
        // 墙插放在最后：它就是系统 + 电池，三个数摆一起永远对得上
        snap.wallW = PowerMath.pickWall(contract: SMCPower.read("PDTR")?.value,
                                        telemetry: telMW("SystemPowerIn") / 1000,
                                        plugged: snap.isPluggedIn,
                                        system: snap.systemLoadW,
                                        battery: snap.batteryW,
                                        draining: snap.batteryDraining)

        // 充满时间自己算：系统给的 AvgTimeToFull 在"没在充"时是垃圾（和 TimeRemaining 同值，
        // 实测 43% 充着电却报 235 分钟）。剩余容量 ÷ 当前功率更实在
        let cellV = volt / 1000
        if snap.isCharging, snap.batteryW > 0.5, snap.fullCapacity > snap.currentCapacity, cellV > 5 {
            let wh = Double(snap.fullCapacity - snap.currentCapacity) * cellV / 1000
            snap.timeToFull = max(Int((wh / snap.batteryW * 60).rounded()), 1)
        } else if !snap.isCharging && !snap.batteryDraining {
            snap.timeToFull = 0
        }

        let adapter = snap.isPluggedIn ? AdapterInfo.parse(dict["AdapterDetails"]) : nil
        return (snap, adapter)
    }

    private let sm = Smoother()
    private var lastSystemW: Double?      // PSTR 上一次的好值，坏样本时沿用
    private var lastPlugged: Bool?        // 插拔瞬间重置平滑，免得从旧值慢慢爬
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

/// 指数平滑。原来用 8 点均值：一个坏样本要拖满 16 秒才走干净；
/// 而电池的 SBS 每 30 秒才更新一次、一跳就是 10W，均值法在台阶前后各拖一半。
final class Smoother {
    private var state: [String: Double] = [:]
    private let alpha: Double
    init(alpha: Double = 0.55) { self.alpha = alpha }
    func smooth(_ key: String, _ v: Double, alpha: Double? = nil) -> Double {
        guard let last = state[key] else { state[key] = v; return v }
        let a = alpha ?? self.alpha
        let next = last + (v - last) * a
        state[key] = next
        return next
    }
    func reset() { state.removeAll() }
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

extension PowerSnapshot {
    /// 插着 5W 充电器但系统要用 9W：电池得往外补 6.8W（用户截图里那种情况）
    static func demoSupplement() -> PowerSnapshot {
        var d = PowerSnapshot()
        d.hasBattery = true
        d.isPluggedIn = true
        d.isCharging = false
        d.batteryDraining = true
        d.percent = 100
        d.wallW = 2.4
        d.systemLoadW = 9.1
        d.batteryW = 6.8
        d.currentCapacity = 4297
        d.fullCapacity = 4297
        d.designCapacity = 4629
        d.cycleCount = 176
        d.temperature = 31.5
        d.timeToFull = 65535      // 系统"算不出"的哨兵值
        d.timeToEmpty = 182
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

    /// 5W 小充电器：插着，但喂不动整机
    static func demoWeakAdapter() -> AdapterInfo {
        var a = AdapterInfo()
        a.negotiatedW = 5
        a.volts = 5
        a.amps = 1
        a.maxW = 5
        a.tier = 0
        a.name = "5W USB-C Power Adapter"
        a.pdos = [AdapterPDO(volts: 5.0, amps: 1.0)]
        return a
    }
}


// 三个数怎么合成，抽成纯函数：没有真机也能断言（2.1.4 那次快充 0 W 就是这里出的）
enum PowerMath {
    /// 这个瓦数可不可信。遥测块的 BatteryPower 会 uint64 回绕成 1.8e16，
    /// 顶层键偶尔也会缺，不挡在门口就会画出"18446744073709548 W"。
    static func sane(_ v: Double?, limit: Double = 200) -> Double? {
        guard let v, v.isFinite, abs(v) <= limit else { return nil }
        return v
    }

    /// 正数才算读到了（PSTR 实测会蹦出 -4.3 W 这种负值）
    static func sanePositive(_ v: Double?, limit: Double = 200) -> Double? {
        guard let v = sane(v, limit: limit), v > 0.2 else { return nil }
        return v
    }

    /// 电池功率（带符号，正 = 往电池里灌）。三级回退，每一级都要过校验
    static func pickBattery(top: Double?, ampereVolt: Double?, telemetry: Double?) -> Double? {
        for c in [top, ampereVolt, telemetry] {
            if let v = sane(c) { return v }
        }
        return nil
    }

    /// 充/放电方向。电流符号比 IsCharging 可靠：插着 30W 头充到 43% 时
    /// 系统照样报 IsCharging=0，但电流是 +865mA（确实在充），按 flag 画就把方向画反了。
    static func chargeState(signedBatteryW: Double, flag: Bool) -> (charging: Bool, draining: Bool) {
        let draining = signedBatteryW < -0.5
        let charging = signedBatteryW > 0.5 || (flag && !draining)
        return (charging, draining)
    }

    /// 墙插功率：插着电就是「系统 + 电池」，三个数永远自洽。
    /// PDTR 不是实时读数——实测 19.6V×1.425A=27.9W，加不加 CPU 负载都不动，
    /// 它是 PD 合约值，只能当兜底。
    static func pickWall(contract: Double?, telemetry: Double?, plugged: Bool,
                         system: Double, battery: Double, draining: Bool) -> Double {
        guard plugged else { return 0 }
        let sum = system + (draining ? -battery : battery)
        if system > 0.2, sum > 0.3 { return sum }
        if let c = sane(contract, limit: 400) { return c }
        if let t = sane(telemetry, limit: 400) { return t }
        return max(sum, 0)
    }

    /// 系统功耗：插电时取「墙插 − 电池」的残差，保证 墙插 = 系统 + 电池。
    /// 放电时电池吐出来的都给了系统，也用电池功率，图上才是一根对得上的带子；
    /// PSTR 在电池端是 DC-DC 之后的数，比电池端低 0.7W，摆在一起又变成"对不上"。
    static func pickSystem(wall: Double, battery: Double, draining: Bool,
                           plugged: Bool, measured: Double, hasBattery: Bool) -> Double {
        if plugged, wall > 0.5, hasBattery {
            return max(wall - (draining ? -battery : battery), 0.3)
        }
        if hasBattery { return battery }
        return measured > 0.5 ? measured : battery
    }
}
