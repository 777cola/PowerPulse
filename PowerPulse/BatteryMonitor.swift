import Foundation
import IOKit
import IOKit.ps

// MARK: - Power Flow Data Model
//
// 数据来源：IORegistry → AppleSmartBattery → PowerTelemetryData
//
// SystemPowerIn: 墙插输入功率 (mW)
// SystemLoad:    系统总负载 (mW) = 系统消耗 + 电池充电功率
// BatteryPower:  电池功率 (mW)，符号不一致，用绝对值
// AdapterEfficiencyLoss: 适配器损耗 (mW)
//
// IsCharging / ExternalConnected: 电池状态标志

struct PowerFlowData {
    let wallPower: Double           // 墙插输出 (W)
    let systemLoad: Double          // 系统总负载 (W)
    let batteryRate: Double         // 电池功率绝对值 (W)
    let adapterLoss: Double         // 适配器损耗 (W)
    let isCharging: Bool
    let isPluggedIn: Bool
    let batteryPercent: Int
    let timestamp: Date
    
    // 系统实际消耗
    var systemUsage: Double {
        if isPluggedIn {
            // 插电时：系统消耗 = 墙插 - 电池充电功率
            return max(wallPower - batteryRate, 0)
        }
        // 电池供电：系统消耗 = 电池放电功率
        return batteryRate
    }
    
    // 电池充电功率（仅充电时）
    var batteryChargeRate: Double {
        isCharging ? batteryRate : 0
    }
    
    // 电池放电功率（仅放电时）
    var batteryDischargeRate: Double {
        (!isPluggedIn || !isCharging) ? batteryRate : 0
    }
    
    static let zero = PowerFlowData(
        wallPower: 0, systemLoad: 0, batteryRate: 0,
        adapterLoss: 0, isCharging: false, isPluggedIn: false,
        batteryPercent: 0, timestamp: Date()
    )
}

// MARK: - Moving Average

final class MovingAverage {
    private let windowSize: Int
    private var values: [Double] = []
    
    init(windowSize: Int = 10) {
        self.windowSize = windowSize
    }
    
    func add(_ value: Double) {
        values.append(value)
        if values.count > windowSize {
            values.removeFirst()
        }
    }
    
    var average: Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    
    func reset() {
        values.removeAll()
    }
}

// MARK: - Battery Monitor

final class BatteryMonitor: ObservableObject {
    @Published var flowData: PowerFlowData = .zero
    @Published var smoothedData: PowerFlowData = .zero
    @Published var batteryPercent: Int = 0
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    
    private var timer: Timer?
    private let updateInterval: TimeInterval = 1.0
    
    // Moving averages for smoothing
    private let wallPowerAvg = MovingAverage(windowSize: 10)
    private let systemLoadAvg = MovingAverage(windowSize: 10)
    private let batteryRateAvg = MovingAverage(windowSize: 10)
    
    func start() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
    }
    
    func update() {
        let data = readPowerFlowData()
        
        // Feed into moving averages
        wallPowerAvg.add(data.wallPower)
        systemLoadAvg.add(data.systemLoad)
        batteryRateAvg.add(data.batteryRate)
        
        let smoothed = PowerFlowData(
            wallPower: wallPowerAvg.average,
            systemLoad: systemLoadAvg.average,
            batteryRate: batteryRateAvg.average,
            adapterLoss: data.adapterLoss,
            isCharging: data.isCharging,
            isPluggedIn: data.isPluggedIn,
            batteryPercent: data.batteryPercent,
            timestamp: data.timestamp
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.flowData = data
            self.smoothedData = smoothed
            self.batteryPercent = data.batteryPercent
            self.isCharging = data.isCharging
            self.isPluggedIn = data.isPluggedIn
        }
    }
    
    private func readPowerFlowData() -> PowerFlowData {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != IO_OBJECT_NULL else { return .zero }
        defer { IOObjectRelease(service) }
        
        var properties: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let dict = properties?.takeRetainedValue() as? [String: Any] else {
            return .zero
        }
        
        let telemetry = dict["PowerTelemetryData"] as? [String: Any] ?? [:]
        
        // Helper: 从 NSNumber 安全读取为 UInt64
        func readUInt64(_ key: String) -> UInt64 {
            guard let num = telemetry[key] as? NSNumber else { return 0 }
            return num.uint64Value
        }
        
        // 读取原始毫瓦值，BatteryPower 可能为负（充电时），用 NSNumber 统一读取
        let wallPower = Double(readUInt64("SystemPowerIn")) / 1000.0
        let systemLoad = Double(readUInt64("SystemLoad")) / 1000.0
        let batteryRaw = readUInt64("BatteryPower")
        let batterySigned = Int64(bitPattern: batteryRaw)  // 无符号→有符号
        let batteryRate = abs(Double(batterySigned)) / 1000.0
        let adapterLoss = Double(readUInt64("AdapterEfficiencyLoss")) / 1000.0
        
        let isCharging = dict["IsCharging"] as? Bool ?? false
        let externalConnected = dict["ExternalConnected"] as? Bool ?? false
        let currentCapacity = dict["CurrentCapacity"] as? Int ?? 0
        
        return PowerFlowData(
            wallPower: wallPower,
            systemLoad: systemLoad,
            batteryRate: batteryRate,
            adapterLoss: adapterLoss,
            isCharging: isCharging,
            isPluggedIn: externalConnected,
            batteryPercent: currentCapacity,
            timestamp: Date()
        )
    }
}
