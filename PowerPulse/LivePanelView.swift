import SwiftUI

// MARK: - Main Popover Content

struct LivePanelView: View {
    @ObservedObject var batteryMonitor: BatteryMonitor
    @ObservedObject var historyStore: PowerHistoryStore
    @ObservedObject var systemMonitor: SystemMonitor
    @State private var selectedTab: Tab = .powerFlow
    @Environment(\.colorScheme) var colorScheme
    
    enum Tab {
        case powerFlow
        case systemMonitor
        case history
        case about
    }
    
    var body: some View {
        ZStack {
            // Glass background
            VisualEffectView(
                material: .hudWindow,
                blendingMode: .behindWindow,
                state: .active
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                switch selectedTab {
                case .powerFlow:
                    mainPanel
                case .systemMonitor:
                    SystemMonitorPanelView(systemMonitor: systemMonitor)
                case .history:
                    historyPanel
                case .about:
                    aboutPanel
                }
                
                bottomNav
            }
        }
        .frame(width: 320)
    }
    
    // MARK: - Main Panel (Power Flow)
    
    private var mainPanel: some View {
        VStack(spacing: 12) {
            // Power Flow Animation
            PowerFlowView(flowData: batteryMonitor.smoothedData)
            
            // Metrics row
            metricsRow
            
            Spacer(minLength: 4)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Metrics Row
    
    private var metricsRow: some View {
        let flow = batteryMonitor.smoothedData
        
        return HStack(spacing: 8) {
            PowerMetricCard(
                title: "墙插输出",
                value: String(format: "%.0f W", flow.wallPower),
                icon: "powerplug.fill",
                color: .primary
            )
            
            PowerMetricCard(
                title: "系统功耗",
                value: String(format: "%.0f W", flow.systemUsage),
                icon: "desktopcomputer",
                color: .blue
            )
            
            PowerMetricCard(
                title: flow.isCharging ? "充电功率" : "电池输出",
                value: String(format: "%.1f W", flow.isCharging ? flow.batteryChargeRate : flow.batteryDischargeRate),
                icon: flow.isCharging ? "battery.100.bolt" : "battery.25",
                color: flow.isCharging ? .green : .orange
            )
            
            PowerMetricCard(
                title: "电池 \(flow.batteryPercent)%",
                value: batteryStatusText,
                icon: batteryIconName,
                color: batteryColor
            )
        }
        .padding(.horizontal, 16)
    }
    
    private var batteryStatusText: String {
        let flow = batteryMonitor.flowData
        if flow.isCharging {
            return "充电中"
        } else if flow.isPluggedIn {
            // Plugged in but not charging
            if flow.batteryPercent >= 99 {
                return "已充满"
            }
            return "外接电源"
        } else {
            return "放电中"
        }
    }
    
    private var batteryIconName: String {
        let flow = batteryMonitor.flowData
        if flow.isCharging { return "bolt.fill" }
        if flow.batteryPercent <= 25 { return "battery.25" }
        if flow.batteryPercent <= 50 { return "battery.50" }
        if flow.batteryPercent <= 75 { return "battery.75" }
        return "battery.100"
    }
    
    private var batteryColor: Color {
        let flow = batteryMonitor.flowData
        if flow.isCharging { return .green }
        if flow.batteryPercent <= 20 { return .red }
        if flow.batteryPercent <= 50 { return .orange }
        return .primary
    }
    
    // MARK: - History Panel
    
    private var historyPanel: some View {
        VStack(spacing: 12) {
            let stats = historyStore.currentSessionStats
            HStack(spacing: 8) {
                statCard(title: "累计充入", value: String(format: "%.2f Wh", stats.totalWh))
                statCard(title: "平均功率", value: String(format: "%.1f W", stats.avgW))
                statCard(title: "峰值功率", value: String(format: "%.1f W", stats.peakW))
                statCard(title: "充电时长", value: "\(stats.durationMin) min")
            }
            .padding(.horizontal, 16)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("充电历史")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HistoryChartView(samples: historyStore.allSamples)
            }
            .padding(.horizontal, 16)
            
            Spacer(minLength: 8)
        }
        .padding(.top, 16)
    }
    
    private func statCard(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .modifier(GlassCardModifier())
    }
    
    // MARK: - About Panel
    
    private var aboutPanel: some View {
        VStack(spacing: 0) {
            // App icon area
            VStack(spacing: 12) {
                Spacer()
                    .frame(height: 24)
                
                // App icon
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.blue.opacity(0.8), .purple.opacity(0.6)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 72, height: 72)
                    
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 32, weight: .bold))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 4) {
                    Text("PowerPulse")
                        .font(.system(size: 20, weight: .bold))
                    
                    Text("v1.0.0")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                
                Text("macOS 菜单栏电源 & 系统监控工具")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            
            Spacer()
                .frame(height: 28)
            
            // Info cards
            VStack(spacing: 8) {
                aboutRow(icon: "person.fill", title: "开发者", value: "AutumnPants")
                aboutRow(icon: "swift", title: "技术栈", value: "Swift · SwiftUI · IOKit")
                aboutRow(icon: "desktopcomputer", title: "兼容性", value: "macOS 14.0+")
                aboutRow(icon: "doc.text.fill", title: "开源协议", value: "MIT License")
            }
            .padding(.horizontal, 16)
            
            Spacer()
            
            // Footer
            VStack(spacing: 4) {
                Divider()
                    .padding(.horizontal, 16)
                
                Text("Made with ❤️ by AutumnPants")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
                    .padding(.bottom, 12)
            }
        }
    }
    
    private func aboutRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundColor(.accentColor)
                .frame(width: 20)
            
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .modifier(GlassCardModifier())
    }
    
    // MARK: - Bottom Navigation
    
    private var bottomNav: some View {
        HStack(spacing: 0) {
            navButton(icon: "bolt.horizontal", title: "功率流", isActive: selectedTab == .powerFlow) {
                selectedTab = .powerFlow
            }
            navButton(icon: "cpu", title: "系统监控", isActive: selectedTab == .systemMonitor) {
                selectedTab = .systemMonitor
            }
            navButton(icon: "clock.arrow.circlepath", title: "充电历史", isActive: selectedTab == .history) {
                selectedTab = .history
            }
            navButton(icon: "info.circle", title: "关于", isActive: selectedTab == .about) {
                selectedTab = .about
            }
            navButton(icon: "power", title: "退出", isActive: false) {
                NSApp.terminate(nil)
            }
        }
        .padding(.vertical, 8)
        .background(
            VisualEffectView(material: .headerView, blendingMode: .withinWindow)
        )
    }
    
    private func navButton(icon: String, title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 3) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                Text(title)
                    .font(.system(size: 9))
            }
            .foregroundColor(isActive ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
