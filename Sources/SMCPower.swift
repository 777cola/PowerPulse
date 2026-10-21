import Foundation
import IOKit

/// AppleSMC 的电源相关读数。
///
/// 台式机（Mac Studio / mini / Pro）没有 AppleSmartBattery，拿不到
/// PowerTelemetryData；SMC 是另一条路，不需要 root。键是否存在、单位是什么，
/// 每代机器不一样，所以这里只做"读到就用、读不到就算了"。
enum SMCPower {
    private static let selector: UInt32 = 2
    private static let structSize = 80
    private static let cmdReadKeyInfo: UInt8 = 9
    private static let cmdReadBytes: UInt8 = 5

    private static var connection: io_connect_t = 0
    private static var opened = false

    private static func fourCC(_ s: String) -> UInt32 { s.utf8.reduce(0) { ($0 << 8) | UInt32($1) } }

    private static func str4(_ v: UInt32) -> String {
        let b = [UInt8((v >> 24) & 0xff), UInt8((v >> 16) & 0xff), UInt8((v >> 8) & 0xff), UInt8(v & 0xff)]
        return String(bytes: b, encoding: .ascii) ?? "????"
    }

    private static func put(_ b: inout [UInt8], _ off: Int, _ v: UInt32) {
        b[off] = UInt8(v & 0xff); b[off + 1] = UInt8((v >> 8) & 0xff)
        b[off + 2] = UInt8((v >> 16) & 0xff); b[off + 3] = UInt8((v >> 24) & 0xff)
    }

    private static func get(_ b: [UInt8], _ off: Int) -> UInt32 {
        UInt32(b[off]) | UInt32(b[off + 1]) << 8 | UInt32(b[off + 2]) << 16 | UInt32(b[off + 3]) << 24
    }

    private static func open() -> Bool {
        if opened { return connection != 0 }
        opened = true
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSMC"))
        guard svc != IO_OBJECT_NULL else { return false }
        defer { IOObjectRelease(svc) }
        return IOServiceOpen(svc, mach_task_self_, 0, &connection) == KERN_SUCCESS
    }

    private static func call(_ input: [UInt8]) -> [UInt8]? {
        var out = [UInt8](repeating: 0, count: structSize)
        var outSize = structSize
        let kr = input.withUnsafeBytes { ip in
            out.withUnsafeMutableBytes { op in
                IOConnectCallStructMethod(connection, selector, ip.baseAddress!, structSize, op.baseAddress!, &outSize)
            }
        }
        return kr == KERN_SUCCESS ? out : nil
    }

    /// 读一个键，返回 (数据类型, 数值)。读不到返回 nil。
    static func read(_ name: String) -> (type: String, value: Double)? {
        guard open() else { return nil }

        var info = [UInt8](repeating: 0, count: structSize)
        put(&info, 0, fourCC(name))
        info[42] = cmdReadKeyInfo
        guard let r1 = call(info), r1[40] == 0 else { return nil }
        let size = get(r1, 28)
        let type = str4(get(r1, 32))

        var rd = [UInt8](repeating: 0, count: structSize)
        put(&rd, 0, fourCC(name))
        put(&rd, 28, size)
        rd[42] = cmdReadBytes
        guard let r2 = call(rd), r2[40] == 0 else { return nil }

        let bytes = Array(r2[48..<(48 + max(4, Int(min(size, 32))))])
        switch type {
        case "flt ":
            return (type, Double(bytes.withUnsafeBytes { $0.load(as: Float.self) }))
        case "sp78":
            let raw = Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))
            return (type, Double(raw) / 256.0)
        case "ui8 ": return (type, Double(bytes[0]))
        case "ui16": return (type, Double(UInt16(bytes[0]) << 8 | UInt16(bytes[1])))
        case "ui32":
            let v = UInt32(bytes[0]) << 24 | UInt32(bytes[1]) << 16 | UInt32(bytes[2]) << 8 | UInt32(bytes[3])
            return (type, Double(v))
        default:
            return nil
        }
    }

    /// 台式机整机功率：先试 PSTR，再试 PDTR。
    /// 都是 Watt 量级的浮点；读不到就返回 nil，让界面显示 —（宁可空着也不写错的数）。
    static func systemWatts() -> Double? {
        for key in ["PSTR", "PDTR"] {
            if let v = read(key)?.value, v > 0.1, v < 500 { return v }
        }
        return nil
    }

    /// 诊断用：把候选键逐个读一遍
    static func probe() -> [String] {
        let keys = ["#KEY", "PSTR", "PDTR", "PC0C", "PCPC", "PS0P",
                    "PMP0", "PMP1", "PDTR", "AC-W", "VD0R", "ID0R", "B0AC", "TB0T"]
        var lines: [String] = []
        let hasBattery = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery")) != IO_OBJECT_NULL
        lines.append("AppleSmartBattery: " + (hasBattery ? "有（笔记本）" : "没有（台式机）"))
        lines.append("AppleSMC 可打开: " + (open() ? "是" : "否"))
        for k in keys {
            if let r = read(k) {
                lines.append(String(format: "%-5@ type=%@ value=%@", k as NSString, r.type, String(format: "%.3f", r.value)))
            } else {
                lines.append("\(k) 读不到")
            }
        }
        return lines
    }
}
