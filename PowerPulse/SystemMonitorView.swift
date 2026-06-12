import SwiftUI
import Charts

// MARK: - System Usage Chart View

struct SystemUsageChartView: View {
    let samples: [SystemUsageSample]
    let metric: SystemMetric
    
    @Environment(\.colorScheme) var colorScheme
    
    enum SystemMetric: String, CaseIterable {
        case cpu = "CPU"
        case gpu = "GPU"
        case memory = "内存"
    }
    
    private var color: Color {
        switch metric {
        case .cpu: return .blue
        case .gpu: return .purple
        case .memory: return .orange
        }
    }
    
    var body: some View {
        if samples.isEmpty {
            emptyChart
        } else {
            chartContent
        }
    }
    
    private var emptyChart: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.1))
            .frame(height: 100)
            .overlay(
                Text("等待数据…")
                    .font(.caption)
                    .foregroundColor(.secondary)
            )
    }
    
    private var chartContent: some View {
        Chart {
            ForEach(samples) { sample in
                LineMark(
                    x: .value("时间", sample.timestamp),
                    y: .value("使用率", value(for: sample))
                )
                .foregroundStyle(color.gradient)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("时间", sample.timestamp),
                    y: .value("使用率", value(for: sample))
                )
                .foregroundStyle(
                    color.opacity(0.15).gradient
                )
                .interpolationMethod(.catmullRom)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .second, count: 30)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [2, 4]))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel(format: .dateTime.minute().second())
                    .font(.system(size: 8))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [2, 4]))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))%")
                            .font(.system(size: 8))
                    }
                }
            }
        }
        .chartYScale(domain: 0...100)
        .frame(height: 100)
        .chartLegend(.hidden)
    }
    
    private func value(for sample: SystemUsageSample) -> Double {
        switch metric {
        case .cpu: return sample.cpuUsage
        case .gpu: return sample.gpuUsage
        case .memory: return sample.memoryUsage
        }
    }
}

// MARK: - System Monitor Panel View

struct SystemMonitorPanelView: View {
    @ObservedObject var systemMonitor: SystemMonitor
    
    var body: some View {
        VStack(spacing: 12) {
            // 指标卡片
            metricsRow
            
            // 图表
            VStack(alignment: .leading, spacing: 8) {
                Text("系统利用率")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 6) {
                    SystemUsageChartView(
                        samples: systemMonitor.samples,
                        metric: .cpu
                    )
                    
                    SystemUsageChartView(
                        samples: systemMonitor.samples,
                        metric: .gpu
                    )
                    
                    SystemUsageChartView(
                        samples: systemMonitor.samples,
                        metric: .memory
                    )
                }
            }
            .padding(.horizontal, 16)
            
            Spacer(minLength: 8)
        }
        .padding(.top, 8)
    }
    
    // MARK: - Metrics Row
    
    private var metricsRow: some View {
        let sample = systemMonitor.currentSample
        
        return HStack(spacing: 8) {
            MetricCard(
                title: "CPU",
                value: String(format: "%.0f%%", sample.cpuUsage),
                icon: "cpu",
                color: .blue
            )
            
            MetricCard(
                title: "GPU",
                value: String(format: "%.0f%%", sample.gpuUsage),
                icon: "display",
                color: .purple
            )
            
            MetricCard(
                title: "内存",
                value: String(format: "%.0f%%", sample.memoryUsage),
                icon: "memorychip",
                color: .orange
            )
            
            MetricCard(
                title: "已用内存",
                value: String(format: "%.1f/%.1f GB", sample.memoryUsedGB, sample.memoryTotalGB),
                icon: "internaldrive",
                color: .primary
            )
        }
        .padding(.horizontal, 16)
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            
            Text(title)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.05))
        )
    }
}