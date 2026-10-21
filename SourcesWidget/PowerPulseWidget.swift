import SwiftUI
import WidgetKit

// MARK: - Timeline

struct Entry: TimelineEntry {
    let date: Date
    let snap: WidgetSnapshot
}

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> Entry {
        var s = WidgetSnapshot()
        s.percent = 72; s.charging = true; s.plugged = true
        s.wallW = 48; s.systemW = 9; s.batteryW = 39
        s.adapterW = 60; s.adapterMax = 60; s.temp = 33.5
        s.timeToFull = 64; s.health = 92.9
        return Entry(date: Date(), snap: s)
    }

    func getSnapshot(in context: Context, completion: @escaping (Entry) -> Void) {
        completion(Entry(date: Date(), snap: .load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> Void) {
        let entry = Entry(date: Date(), snap: .load())
        // 主 app 在状态变化时会主动 reload；这里兜底每 5 分钟一次
        let next = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
        completion(Timeline(entries: [entry], policy: .after(next)))
    }
}

// MARK: - 视图

struct WidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: Entry
    @Environment(\.colorScheme) private var scheme

    private var s: WidgetSnapshot { entry.snap }

    /// 台式机没有电池，任何 0% 都是假的
    private var percentText: String { s.hasBattery ? "\(s.percent)" : "—" }

    private var accent: Color {
        if !s.hasBattery { return .blue }
        if s.charging { return .green }
        if s.plugged { return .purple }
        return s.percent <= 20 ? .red : .primary
    }

    var body: some View {
        Group {
            switch family {
            case .systemMedium: medium
            default: small
            }
        }
    }

    private var small: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 5) {
                Image(systemName: s.symbolName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(accent)
                Text(s.stateText)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }
            Spacer(minLength: 0)
            HStack(alignment: .firstTextBaseline, spacing: 1) {
                Text(percentText)
                    .font(.system(size: 40, weight: .light, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(.primary)
                Text("%")
                    .font(.system(size: 15, weight: .regular, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            HStack(spacing: 4) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 9))
                    .foregroundStyle(accent)
                Text("\(Int(s.plugged ? s.wallW.rounded() : s.systemW.rounded())) W")
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .monospacedDigit()
                Spacer(minLength: 0)
                Text(s.plugged ? "档位 \(Int(s.adapterW))/\(Int(s.adapterMax))" : restText)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var medium: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: s.symbolName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(accent)
                Text(s.stateText)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(s.plugged ? "套装上限 \(Int(s.adapterMax))W" : "电池健康 \(String(format: "%.0f", s.health))%")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(percentText)
                    .font(.system(size: 34, weight: .light, design: .rounded))
                    .monospacedDigit()
                Text("%")
                    .font(.system(size: 14, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("墙插 \(Int(s.wallW.rounded())) W")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .monospacedDigit()
                    Text("系统 \(Int(s.systemW.rounded())) W")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            // 电量条（台式机没有）
            if s.hasBattery {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.09))
                        Capsule().fill(accent.opacity(0.75))
                            .frame(width: max(geo.size.width * CGFloat(min(max(s.percent, 0), 100)) / 100, 4))
                    }
                }
                .frame(height: 6)
            }
            HStack(spacing: 4) {
                Text(s.hasBattery ? (s.charging ? "电池 \(String(format: "%.1f", s.batteryW)) W 充入 · \(remainText)" : "电池放电 \(String(format: "%.1f", s.batteryW)) W · \(remainText)") : "插电直供 · 无电池")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                Spacer()
                if s.temp > 0 {
                    Text(String(format: "%.1f ℃", s.temp))
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var restText: String {
        guard s.timeToEmpty > 0 else { return "—" }
        return "剩 \(s.timeToEmpty / 60):" + String(format: "%02d", s.timeToEmpty % 60)
    }

    private var remainText: String {
        if s.charging, s.timeToFull > 0 {
            return "\(s.timeToFull / 60)h\(String(format: "%02d", s.timeToFull % 60))m 充满"
        }
        if s.timeToEmpty > 0 {
            return "剩 \(s.timeToEmpty / 60):" + String(format: "%02d", s.timeToEmpty % 60)
        }
        return "—"
    }
}

// MARK: - Widget
// 多个 @Widget 放在一个 bundle 里；这是 SwiftUI 只有装了 Xcode 才能编译的原因。

struct PowerPulseWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "PowerPulseWidget", provider: Provider()) { entry in
            WidgetView(entry: entry)
                .containerBackground(.regularMaterial, for: .widget)
        }
        .configurationDisplayName("PowerPulse")
        .description("电池电量、实时功率与充电器档位")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct PowerPulseWidgetBundle: WidgetBundle {
    var body: some Widget {
        PowerPulseWidget()
    }
}
