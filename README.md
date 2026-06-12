<p align="center">
  <strong>⚡ PowerPulse</strong><br>
  <em>macOS menu bar power & system monitor</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-blue" alt="macOS 14+">
  <img src="https://img.shields.io/badge/Swift-6.3-orange" alt="Swift 6.3">
  <img src="https://img.shields.io/badge/License-MIT-green" alt="License: MIT">
</p>

---

<p align="center">
  <strong>⚡ PowerPulse</strong><br>
  <em>macOS 菜单栏电源 & 系统监控工具</em>
</p>

<!-- Screenshots -->
<p align="center">
  <img src="screenshots/power-flow.png" width="300" alt="Power Flow">
  &nbsp;&nbsp;
  <img src="screenshots/system-monitor.png" width="300" alt="System Monitor">
  &nbsp;&nbsp;
  <img src="screenshots/charging-history.png" width="300" alt="Charging History">
</p>

## Features / 功能特性

### Menu Bar / 菜单栏

- Real-time wattage display with tabular (monospace) digits — no layout shift
- Auto-switching icons: ⚡ Charging / 🔌 Plugged In / 🔋 On Battery
- Battery percentage + mini battery icon

实时显示当前功率，等宽数字避免跳动。自动切换 ⚡🔌🔋 图标。

### Power Panel / 电源面板

- Battery in/out wattage
- Charger rated wattage
- System total power draw
- Battery percentage with visual gauge
- Charger name & specs (V/A)
- Real-time power chart (last 60s, 2s sample rate)

显示充放电功率、充电器信息、系统总功耗，附带实时功率曲线图。

### System Monitor / 系统监控

- CPU usage (per-core average)
- GPU usage (via IORegistry / Metal)
- Memory usage (used / total in GB)
- 5-minute history charts for each metric
- 2-second refresh rate, ~150 sample buffer

实时监控 CPU、GPU、内存使用率，每个指标独立图表，显示最近 5 分钟趋势。

### History & Export / 历史与导出

- Cumulative charge (Wh), average/peak power, charge duration
- Export charging data to CSV

累计充电量、平均/峰值功率、充电时长，支持导出 CSV。

### Appearance / 外观

- **Classic** — solid panel, auto dark/light
- **Glass** — NSVisualEffectView frosted glass
- Follow System

经典模式（不透明）、毛玻璃模式、跟随系统。

## Requirements / 系统要求

- macOS 14.0 (Sonoma) or later
- Swift 6.3+ (Xcode 16+)

## Build / 构建

```bash
git clone https://github.com/777cola/PowerPulse.git
cd powerpulse
swift build -c release
cp -r .build/release/PowerPulse PowerPulse.app
open PowerPulse.app
```

Or use the build script:

```bash
./build_app.sh
```

## Project Structure / 项目结构

```
PowerPulse/
├── Package.swift                 # SPM configuration
├── build_app.sh                  # Build script
├── PowerPulse/
│   ├── ChargeWatchApp.swift      # App entry + AppDelegate
│   ├── BatteryMonitor.swift      # IOKit battery data
│   ├── PowerHistoryStore.swift   # Historical data persistence
│   ├── PowerFlowView.swift       # Power flow visualization
│   ├── Models.swift              # Data models
│   ├── Charts.swift              # Chart components
│   ├── LivePanelView.swift       # Main panel UI
│   ├── Appearance.swift          # Theme system
│   ├── SystemMonitor.swift       # CPU/GPU/Memory data collection
│   └── SystemMonitorView.swift   # System monitor UI & charts
├── LICENSE
└── README.md
```

## Technical Details / 技术细节

| Component | API |
|-----------|-----|
| Battery data | IOKit (AppleSmartBattery) |
| CPU usage | `host_processor_info()` |
| GPU usage | IORegistry (IOAccelerator PerformanceStatistics) |
| Memory | `host_statistics64()` |
| UI | SwiftUI + AppKit |
| Charts | Swift Charts |
| Theme | NSVisualEffectView |

## License / 开源协议

[MIT](LICENSE) © [AutumnPants](https://github.com/777cola)
