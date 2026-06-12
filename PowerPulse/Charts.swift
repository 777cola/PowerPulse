import SwiftUI
import Charts

// MARK: - Real-time Power Line Chart

struct PowerLineChart: View {
    let samples: [PowerSample]
    let showBattery: Bool
    
    @Environment(\.colorScheme) var colorScheme
    
    init(samples: [PowerSample], showBattery: Bool = false) {
        self.samples = samples
        self.showBattery = showBattery
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
            .frame(height: 120)
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
                    y: .value("功率 W", sample.watts)
                )
                .foregroundStyle(Color.green.gradient)
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("时间", sample.timestamp),
                    y: .value("功率 W", sample.watts)
                )
                .foregroundStyle(
                    Color.green.opacity(0.15).gradient
                )
                .interpolationMethod(.catmullRom)
            }
            
            if showBattery {
                ForEach(samples) { sample in
                    LineMark(
                        x: .value("时间", sample.timestamp),
                        y: .value("电量 %", Double(sample.batteryPercent))
                    )
                    .foregroundStyle(Color.orange.gradient)
                    .lineStyle(StrokeStyle(dash: [5, 3]))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .second, count: 15)) { _ in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [2, 4]))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel(format: .dateTime.hour().minute().second())
                    .font(.system(size: 8))
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3, dash: [2, 4]))
                    .foregroundStyle(Color.gray.opacity(0.3))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))W")
                            .font(.system(size: 8))
                    }
                }
            }
        }
        .chartYScale(domain: 0...max(ceil(maxWatt * 1.2), 10))
        .frame(height: 120)
        .chartLegend(.hidden)
    }
    
    private var maxWatt: Double {
        samples.map(\.watts).max() ?? 10
    }
}

// MARK: - History Chart (for history panel)

struct HistoryChartView: View {
    let samples: [PowerSample]
    
    var body: some View {
        if samples.isEmpty {
            emptyView
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Chart {
                    ForEach(samples) { sample in
                        LineMark(
                            x: .value("时间", sample.timestamp),
                            y: .value("功率", sample.watts)
                        )
                        .foregroundStyle(Color.green.gradient)
                        .interpolationMethod(.catmullRom)
                        
                        AreaMark(
                            x: .value("时间", sample.timestamp),
                            y: .value("功率", sample.watts)
                        )
                        .foregroundStyle(Color.green.opacity(0.1).gradient)
                        .interpolationMethod(.catmullRom)
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .hour, count: 1)) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisValueLabel(format: .dateTime.hour())
                            .font(.system(size: 9))
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .trailing) { value in
                        AxisGridLine(stroke: StrokeStyle(lineWidth: 0.3))
                            .foregroundStyle(Color.gray.opacity(0.3))
                        AxisValueLabel {
                            if let v = value.as(Double.self) {
                                Text("\(Int(v))")
                                    .font(.system(size: 9))
                            }
                        }
                    }
                }
                .frame(height: 200)
            }
        }
    }
    
    private var emptyView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.08))
            .frame(height: 200)
            .overlay(
                VStack(spacing: 8) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("暂无充电记录")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            )
    }
}
