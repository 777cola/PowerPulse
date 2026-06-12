import Foundation
import AppKit
import Combine

// MARK: - Power History Store

final class PowerHistoryStore: ObservableObject {
    @Published var recentSamples: [PowerSample] = []
    @Published var allSamples: [PowerSample] = []
    @Published var sessions: [ChargingSession] = []
    @Published var currentSession: ChargingSession?
    
    private let maxRecentSamples = 30
    private let sampleInterval: TimeInterval = 2.0
    private var lastSampleTime: Date = .distantPast
    
    private let saveURL: URL
    
    init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("PowerPulse", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        saveURL = dir.appendingPathComponent("power_history.json")
        loadData()
    }
    
    // MARK: - 插上充电器时重置历史（只保留本次充电数据）
    
    func resetForNewChargingSession() {
        // 保存旧 session
        if var session = currentSession {
            session.end()
            sessions.append(session)
        }
        // 清空当前数据，从头开始
        recentSamples.removeAll()
        allSamples.removeAll()
        currentSession = nil
        saveData()
    }
    
    // MARK: - Add Sample
    
    func addSample(_ sample: PowerSample) {
        let now = sample.timestamp
        guard now.timeIntervalSince(lastSampleTime) >= sampleInterval * 0.8 else { return }
        lastSampleTime = now
        
        recentSamples.append(sample)
        if recentSamples.count > maxRecentSamples {
            recentSamples.removeFirst(recentSamples.count - maxRecentSamples)
        }
        
        allSamples.append(sample)
        
        updateSession(with: sample)
        
        if allSamples.count % 15 == 0 {
            saveData()
        }
    }
    
    // MARK: - Session Management
    
    private func updateSession(with sample: PowerSample) {
        if sample.isCharging {
            if currentSession == nil {
                currentSession = ChargingSession(startTime: sample.timestamp)
            }
            currentSession?.addSample(watts: sample.watts, intervalSeconds: sampleInterval)
        } else {
            if var session = currentSession {
                session.end()
                sessions.append(session)
                currentSession = nil
                saveData()
            }
        }
    }
    
    // MARK: - Stats（只统计当前 session）
    
    var currentSessionStats: (totalWh: Double, avgW: Double, peakW: Double, durationMin: Int) {
        guard let session = currentSession else {
            // 没有活跃 session 时，统计 allSamples
            var totalWh: Double = 0
            var sumW: Double = 0
            var peakW: Double = 0
            var count = 0
            for sample in allSamples where sample.isCharging {
                totalWh += sample.watts * (sampleInterval / 3600.0)
                sumW += sample.watts
                count += 1
                if sample.watts > peakW { peakW = sample.watts }
            }
            let avgW = count > 0 ? sumW / Double(count) : 0
            let durationMin = Int(Double(count) * sampleInterval / 60.0)
            return (totalWh, avgW, peakW, durationMin)
        }
        return (session.totalEnergyWh, session.averageWatts, session.peakWatts, session.durationMinutes)
    }
    
    // MARK: - Persistence
    
    private struct SaveData: Codable {
        var sessions: [ChargingSession]
        var todaySamples: [PowerSample]
    }
    
    func saveData() {
        let data = SaveData(sessions: sessions, todaySamples: allSamples)
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: saveURL)
        }
    }
    
    func loadData() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode(SaveData.self, from: data) else { return }
        sessions = decoded.sessions
        let calendar = Calendar.current
        allSamples = decoded.todaySamples.filter { calendar.isDateInToday($0.timestamp) }
    }
}
