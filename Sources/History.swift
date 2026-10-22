import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

struct SampleRow {
    var ts: Date
    var percent: Int
    var wall: Double
    var system: Double
    var battery: Double
    var charging: Bool
    var temp: Double
    var adapterW: Double
    var adapterMax: Double
}

struct SessionStats {
    var wh: Double = 0
    var avgW: Double = 0
    var peakW: Double = 0
    var seconds: Double = 0
    var isActive = false
}

struct DayStat {
    var date: Date
    var wh: Double
    var peakW: Double
    var seconds: Double
}

// MARK: - 历史存储（SQLite，跨天保留）

final class HistoryStore {
    static let shared = HistoryStore()

    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "com.autumnpants.powerpulse.db", qos: .utility)
    private var lastWrite = Date.distantPast
    private var lastCharging = false
    private var lastPlugged = false
    private var lastWall = Double.nan
    private var lastBattery = Double.nan
    private var lastPercent = -1
    private var cachedRecent: [SampleRow] = []

    var dbPath: String {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return base.appendingPathComponent("PowerPulse/history.db").path
    }

    func open() {
        let dir = (dbPath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        guard sqlite3_open(dbPath, &db) == SQLITE_OK else { return }
        exec("""
        CREATE TABLE IF NOT EXISTS samples(
          ts REAL PRIMARY KEY, percent INTEGER, wall REAL, system REAL,
          battery REAL, charging INTEGER, temp REAL, adapter_w REAL, adapter_max REAL);
        CREATE INDEX IF NOT EXISTS idx_ts ON samples(ts);
        CREATE TABLE IF NOT EXISTS meta(k TEXT PRIMARY KEY, v TEXT);
        """)
        exec("PRAGMA journal_mode=WAL;")
        exec("PRAGMA wal_autocheckpoint=200;")
    }

    private func exec(_ sql: String) {
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    // MARK: 写入

    func record(_ s: PowerSnapshot, adapter: AdapterInfo?) {
        // 以前每 2 秒写一条，一天 2 万行，而 7 天图是按小时聚合的——纯浪费磁盘和唤醒。
        // 现在：插拔/充放切换立刻写；功率挪动 1.5W 以上或电量变了才写；其余 30 秒兜底一条。
        let stateChanged = s.isCharging != lastCharging || s.isPluggedIn != lastPlugged
        let elapsed = Date().timeIntervalSince(lastWrite)
        let moved = abs(s.wallW - lastWall) >= 1.5
            || abs(s.batteryW - lastBattery) >= 1.5
            || s.percent != lastPercent
        let due = elapsed >= 30
        guard stateChanged || (elapsed >= 5 && (moved || due)) else { return }
        lastWrite = Date()
        lastCharging = s.isCharging
        lastPlugged = s.isPluggedIn
        lastWall = s.wallW
        lastBattery = s.batteryW
        lastPercent = s.percent

        queue.async { [weak self] in
            guard let self, self.db != nil else { return }
            let sql = "INSERT OR REPLACE INTO samples(ts,percent,wall,system,battery,charging,temp,adapter_w,adapter_max) VALUES(?,?,?,?,?,?,?,?,?);"
            var st: OpaquePointer?
            guard sqlite3_prepare_v2(self.db, sql, -1, &st, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(st) }
            sqlite3_bind_double(st, 1, s.timestamp.timeIntervalSince1970)
            sqlite3_bind_int(st, 2, Int32(s.percent))
            sqlite3_bind_double(st, 3, s.wallW)
            sqlite3_bind_double(st, 4, s.systemUsageW)
            sqlite3_bind_double(st, 5, s.batteryW)
            sqlite3_bind_int(st, 6, s.isCharging ? 1 : 0)
            sqlite3_bind_double(st, 7, s.temperature)
            sqlite3_bind_double(st, 8, adapter?.negotiatedW ?? 0)
            sqlite3_bind_double(st, 9, adapter?.maxW ?? 0)
            sqlite3_step(st)
        }
    }

    // MARK: 读取

    func recent(minutes: Int = 60) -> [SampleRow] {
        guard db != nil else { return [] }
        let since = Date().timeIntervalSince1970 - Double(minutes * 60)
        var out: [SampleRow] = []
        queue.sync {
            var st: OpaquePointer?
            let sql = "SELECT ts,percent,wall,system,battery,charging,temp,adapter_w,adapter_max FROM samples WHERE ts>=? ORDER BY ts;"
            guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(st) }
            sqlite3_bind_double(st, 1, since)
            while sqlite3_step(st) == SQLITE_ROW {
                out.append(SampleRow(
                    ts: Date(timeIntervalSince1970: sqlite3_column_double(st, 0)),
                    percent: Int(sqlite3_column_int(st, 1)),
                    wall: sqlite3_column_double(st, 2),
                    system: sqlite3_column_double(st, 3),
                    battery: sqlite3_column_double(st, 4),
                    charging: sqlite3_column_int(st, 5) == 1,
                    temp: sqlite3_column_double(st, 6),
                    adapterW: sqlite3_column_double(st, 7),
                    adapterMax: sqlite3_column_double(st, 8)))
            }
        }
        cachedRecent = out
        return out
    }

    /// 最近一次充电（可能已经结束）。以前只统计"正在充电"的会话，
    /// 一旦拔掉电源四张卡就全变 "—"，看着像坏了。
    func currentSession() -> SessionStats {
        var st = SessionStats()
        guard db != nil else { return st }
        queue.sync {
            var rows: [(Date, Double)] = []
            var stmt: OpaquePointer?
            let sql = "SELECT ts,battery,charging FROM samples ORDER BY ts DESC LIMIT 43200;"
            guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(stmt) }

            var started = false
            var firstRowWasCharging = false
            while sqlite3_step(stmt) == SQLITE_ROW {
                let ts = Date(timeIntervalSince1970: sqlite3_column_double(stmt, 0))
                let w = sqlite3_column_double(stmt, 1)
                let ch = sqlite3_column_int(stmt, 2) == 1
                if !started {
                    if !ch { continue }        // 跳过最近的非充电样本，往前找上一段充电
                    started = true
                    firstRowWasCharging = true
                    st.isActive = true
                } else if !ch {
                    break                      // 这段充电结束
                }
                rows.append((ts, w))
            }
            _ = firstRowWasCharging
            guard let newest = rows.first, let oldest = rows.last else { return }
            st.seconds = newest.0.timeIntervalSince(oldest.0)
            for i in 0..<rows.count {
                let dt = i + 1 < rows.count ? rows[i].0.timeIntervalSince(rows[i + 1].0) : 0
                st.wh += rows[i].1 * max(dt, 0) / 3600
                st.peakW = max(st.peakW, rows[i].1)
            }
            st.avgW = rows.map(\.1).reduce(0, +) / Double(rows.count)
        }
        return st
    }

    /// 近 N 天聚合
    func daily(days: Int = 7) -> [DayStat] {
        var out: [DayStat] = []
        guard db != nil else { return [] }
        let since = Calendar.current.startOfDay(for: Date()).timeIntervalSince1970 - Double((days - 1) * 86400)
        queue.sync {
            var st: OpaquePointer?
            let sql = """
            WITH s AS (SELECT ts, charging, battery, LAG(ts) OVER (ORDER BY ts) AS prev
                       FROM samples WHERE ts >= ?)
            SELECT strftime('%Y-%m-%d', ts, 'unixepoch', 'localtime') AS d,
                   SUM(CASE WHEN charging=1 AND prev IS NOT NULL THEN battery*(ts-prev)/3600.0 ELSE 0 END) AS wh,
                   MAX(CASE WHEN charging=1 THEN battery ELSE 0 END) AS peak,
                   SUM(CASE WHEN charging=1 AND prev IS NOT NULL THEN ts-prev ELSE 0 END) AS dur
            FROM s GROUP BY d ORDER BY d;
            """
            guard sqlite3_prepare_v2(db, sql, -1, &st, nil) == SQLITE_OK else { return }
            defer { sqlite3_finalize(st) }
            sqlite3_bind_double(st, 1, since)
            let f = DateFormatter()
            f.dateFormat = "yyyy-MM-dd"
            f.timeZone = .current
            while sqlite3_step(st) == SQLITE_ROW {
                guard let c = sqlite3_column_text(st, 0) else { continue }
                let ds = String(cString: c)
                guard let date = f.date(from: ds) else { continue }
                out.append(DayStat(date: date,
                                   wh: sqlite3_column_double(st, 1),
                                   peakW: sqlite3_column_double(st, 2),
                                   seconds: sqlite3_column_double(st, 3)))
            }
        }
        // 补齐没有记录的日子，保证柱状图连续
        let cal = Calendar.current
        var filled: [DayStat] = []
        for i in 0..<days {
            guard let day = cal.date(byAdding: .day, value: -(days - 1 - i), to: cal.startOfDay(for: Date())) else { continue }
            if let hit = out.first(where: { cal.isDate($0.date, inSameDayAs: day) }) {
                filled.append(hit)
            } else {
                filled.append(DayStat(date: day, wh: 0, peakW: 0, seconds: 0))
            }
        }
        return filled
    }

    // MARK: 维护

    /// 把 WAL 合并回主库，避免 -wal 文件无限长
    func checkpoint() {
        guard db != nil else { return }
        queue.async { [weak self] in
            guard let self else { return }
            self.exec("PRAGMA wal_checkpoint(TRUNCATE);")
        }
    }

    func prune(days: Int) {
        guard days > 0 else { return }
        let cut = Date().timeIntervalSince1970 - Double(days * 86400)
        queue.async { [weak self] in
            guard let self, self.db != nil else { return }
            var st: OpaquePointer?
            if sqlite3_prepare_v2(self.db, "DELETE FROM samples WHERE ts < ?;", -1, &st, nil) == SQLITE_OK {
                sqlite3_bind_double(st, 1, cut)
                sqlite3_step(st)
            }
            sqlite3_finalize(st)
        }
    }

    func clear() {
        queue.async { [weak self] in
            guard let self, self.db != nil else { return }
            self.exec("DELETE FROM samples;")
            self.exec("VACUUM;")
        }
    }

    enum ExportResult {
        case ok(URL)
        case empty
        case failed(String)
    }

    func exportCSV() -> ExportResult {
        let rows = recent(minutes: 60 * 24 * 365)
        guard !rows.isEmpty else { return .empty }
        let f = DateFormatter()
        f.dateFormat = "yyyy/MM/dd HH:mm:ss"
        var csv = "time,percent,wall_w,system_w,battery_w,charging,temp_c,adapter_w,adapter_max_w\n"
        for r in rows {
            csv += "\(f.string(from: r.ts)),\(r.percent),\(String(format: "%.2f", r.wall)),\(String(format: "%.2f", r.system)),\(String(format: "%.2f", r.battery)),\(r.charging ? 1 : 0),\(String(format: "%.2f", r.temp)),\(String(format: "%.1f", r.adapterW)),\(String(format: "%.1f", r.adapterMax))\n"
        }
        let url = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PowerPulse-\(Int(Date().timeIntervalSince1970)).csv")
        do {
            try csv.write(to: url, atomically: true, encoding: .utf8)
            return .ok(url)
        } catch {
            // 没权限（下载目录 TCC）或磁盘满，别再返回一个不存在的路径
            return .failed(error.localizedDescription)
        }
    }
}
