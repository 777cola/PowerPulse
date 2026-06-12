import Foundation
import IOKit
import Metal

// MARK: - System Usage Sample

struct SystemUsageSample: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let cpuUsage: Double      // 0-100
    let gpuUsage: Double      // 0-100
    let memoryUsage: Double   // 0-100
    let memoryUsedGB: Double
    let memoryTotalGB: Double
    
    init(timestamp: Date = Date(), cpuUsage: Double, gpuUsage: Double, memoryUsage: Double, memoryUsedGB: Double, memoryTotalGB: Double) {
        self.id = UUID()
        self.timestamp = timestamp
        self.cpuUsage = cpuUsage
        self.gpuUsage = gpuUsage
        self.memoryUsage = memoryUsage
        self.memoryUsedGB = memoryUsedGB
        self.memoryTotalGB = memoryTotalGB
    }
}

// MARK: - System Monitor

final class SystemMonitor: ObservableObject {
    @Published var currentSample: SystemUsageSample = .init(cpuUsage: 0, gpuUsage: 0, memoryUsage: 0, memoryUsedGB: 0, memoryTotalGB: 0)
    @Published var samples: [SystemUsageSample] = []
    
    private var timer: Timer?
    private let updateInterval: TimeInterval = 2.0
    private let maxSamples = 150  // 约5分钟历史数据
    // CPU 使用率计算相关
    private var previousCPUInfo: processor_info_array_t?
    private var previousCPUInfoCount: mach_msg_type_number_t = 0
    
    func start() {
        update()
        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.update()
        }
    }
    
    func stop() {
        timer?.invalidate()
        timer = nil
        previousCPUInfo = nil
        previousCPUInfoCount = 0
    }
    
    func update() {
        let cpu = getCPUUsage()
        let gpu = getGPUUsage()
        let (memUsed, memTotal, memPercent) = getMemoryUsage()
        
        let sample = SystemUsageSample(
            timestamp: Date(),
            cpuUsage: cpu,
            gpuUsage: gpu,
            memoryUsage: memPercent,
            memoryUsedGB: memUsed,
            memoryTotalGB: memTotal
        )
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.currentSample = sample
            self.samples.append(sample)
            if self.samples.count > self.maxSamples {
                self.samples.removeFirst()
            }
        }
    }
    
    // MARK: - CPU Usage
    
    private func getCPUUsage() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var cpuInfoCount: mach_msg_type_number_t = 0
        
        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &cpuInfoCount)
        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return 0 }
        
        var totalUsage: Double = 0
        var totalCPU: Double = 0
        
        for i in 0..<Int(numCPUs) {
            let offset = Int(CPU_STATE_MAX) * i
            let user = Double(cpuInfo[offset + Int(CPU_STATE_USER)])
            let system = Double(cpuInfo[offset + Int(CPU_STATE_SYSTEM)])
            let idle = Double(cpuInfo[offset + Int(CPU_STATE_IDLE)])
            let nice = Double(cpuInfo[offset + Int(CPU_STATE_NICE)])
            
            let total = user + system + idle + nice
            
            if let prevInfo = previousCPUInfo, previousCPUInfoCount > 0 {
                let prevOffset = Int(CPU_STATE_MAX) * i
                let prevUser = Double(prevInfo[prevOffset + Int(CPU_STATE_USER)])
                let prevSystem = Double(prevInfo[prevOffset + Int(CPU_STATE_SYSTEM)])
                let prevIdle = Double(prevInfo[prevOffset + Int(CPU_STATE_IDLE)])
                let prevNice = Double(prevInfo[prevOffset + Int(CPU_STATE_NICE)])
                let prevTotal = prevUser + prevSystem + prevIdle + prevNice
                
                let deltaTotal = total - prevTotal
                let deltaUsed = (user - prevUser) + (system - prevSystem) + (nice - prevNice)
                
                if deltaTotal > 0 {
                    totalUsage += deltaUsed
                    totalCPU += deltaTotal
                }
            } else {
                totalUsage += user + system + nice
                totalCPU += total
            }
        }
        
        // 保存当前 CPU 信息用于下次计算
        // 先释放旧的
        if let prevInfo = previousCPUInfo, previousCPUInfoCount > 0 {
            let size = MemoryLayout<integer_t>.size * Int(previousCPUInfoCount)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevInfo), vm_size_t(size))
        }
        previousCPUInfo = cpuInfo
        previousCPUInfoCount = cpuInfoCount
        
        guard totalCPU > 0 else { return 0 }
        return min((totalUsage / totalCPU) * 100.0, 100.0)
    }
    
    // MARK: - GPU Usage (Metal)
    
    private func getGPUUsage() -> Double {
        guard let device = MTLCreateSystemDefaultDevice() else { return 0 }
        
        // Metal 没有直接的 GPU 使用率 API
        // 这里通过 IORegistry 获取 GPU 相关信息
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOAccelerator"))
        guard service != IO_OBJECT_NULL else { return 0 }
        defer { IOObjectRelease(service) }
        
        var properties: Unmanaged<CFMutableDictionary>?
        let kr = IORegistryEntryCreateCFProperties(service, &properties, kCFAllocatorDefault, 0)
        guard kr == KERN_SUCCESS, let dict = properties?.takeRetainedValue() as? [String: Any] else {
            return 0
        }
        
        // 尝试获取 GPU 统计信息（数据在 PerformanceStatistics 内）
        if let statistics = dict["PerformanceStatistics"] as? [String: Any] {
            if let deviceUtilization = statistics["Device Utilization %"] as? Int {
                return Double(deviceUtilization)
            }
            if let busyPercent = statistics["GPU Busy"] as? Double {
                return busyPercent
            }
        }
        
        // 兼容旧格式
        if let statistics = dict["Statistics"] as? [String: Any],
           let deviceUtilization = statistics["Device Utilization %"] as? Int {
            return Double(deviceUtilization)
        }
        
        return 0
    }
    
    // MARK: - Memory Usage
    
    private func getMemoryUsage() -> (used: Double, total: Double, percent: Double) {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)
        
        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }
        
        guard result == KERN_SUCCESS else { return (0, 0, 0) }
        
        let pageSize = Double(vm_kernel_page_size)
        let totalMemory = Double(ProcessInfo.processInfo.physicalMemory)
        let totalGB = totalMemory / (1024 * 1024 * 1024)
        
        // 计算已使用内存
        let active = Double(stats.active_count) * pageSize
        let inactive = Double(stats.inactive_count) * pageSize
        let wired = Double(stats.wire_count) * pageSize
        let compressed = Double(stats.compressor_page_count) * pageSize
        let purgeable = Double(stats.purgeable_count) * pageSize
        let external = Double(stats.external_page_count) * pageSize
        
        let usedMemory = active + inactive + wired + compressed - purgeable + external
        let usedGB = usedMemory / (1024 * 1024 * 1024)
        let usagePercent = (usedMemory / totalMemory) * 100.0
        
        return (usedGB, totalGB, min(usagePercent, 100.0))
    }
}