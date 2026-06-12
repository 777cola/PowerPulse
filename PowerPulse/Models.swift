import Foundation

// MARK: - Power Sample (for real-time chart)

struct PowerSample: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let watts: Double
    let batteryPercent: Int
    let isCharging: Bool
    
    init(timestamp: Date = Date(), watts: Double, batteryPercent: Int, isCharging: Bool) {
        self.id = UUID()
        self.timestamp = timestamp
        self.watts = watts
        self.batteryPercent = batteryPercent
        self.isCharging = isCharging
    }
}

// MARK: - Charging Session

struct ChargingSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var peakWatts: Double
    var totalEnergyWh: Double
    var sampleCount: Int
    var sumWatts: Double
    
    var durationSeconds: TimeInterval {
        (endTime ?? Date()).timeIntervalSince(startTime)
    }
    
    var durationMinutes: Int {
        Int(durationSeconds / 60)
    }
    
    var averageWatts: Double {
        sampleCount > 0 ? sumWatts / Double(sampleCount) : 0
    }
    
    var durationFormatted: String {
        let mins = durationMinutes
        if mins < 60 { return "\(mins) min" }
        return "\(mins / 60)h \(mins % 60)m"
    }
    
    init(startTime: Date = Date()) {
        self.id = UUID()
        self.startTime = startTime
        self.endTime = nil
        self.peakWatts = 0
        self.totalEnergyWh = 0
        self.sampleCount = 0
        self.sumWatts = 0
    }
    
    mutating func addSample(watts: Double, intervalSeconds: Double) {
        sampleCount += 1
        sumWatts += watts
        if watts > peakWatts { peakWatts = watts }
        totalEnergyWh += watts * (intervalSeconds / 3600.0)
    }
    
    mutating func end() {
        endTime = Date()
    }
}
