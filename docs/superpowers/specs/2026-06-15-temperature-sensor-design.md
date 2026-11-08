# 温度传感器功能 — 设计规格

> **日期**: 2026-06-15 | **版本**: v1.0 | **关联项目**: PowerPulse

---

## 一、第一性原理分析

### 假设识别与挑战

| # | 原有假设 | 挑战 |
|---|---------|------|
| 1 | 用户只需要关注"电"相关的指标（功率、电量） | 温度是功耗的直接后果，CPU/GPU温度比瓦特数更能反映"我的电脑在发烫"这个直觉痛点 |
| 2 | 系统监控 Tab 已包含 CPU/GPU，温度不应另开 Tab | 系统使用率是"压力"，温度是"后果"，两者属于不同语义维度。分开可降低认知负荷 |
| 3 | macOS 没有公开的温度 API | SMC 是官方 IOKit 路径，虽未文档化但稳定存在十余年，Apple 自己的工具也在用 |

### 基本真理

- **功耗 → 热量**：系统消耗的每一瓦特最终都转化为热量，温度是功耗的积分效应
- **SMC 是唯一来源**：macOS 上所有温度数据（iStat Menus、TG Pro、活动监视器）都读自 `AppleSMC` IOService
- **感知 > 精度**：用户关心的是"烫不烫"（温度条直观），而非 ±1°C 的精度
- **传感器数量因机而异**：Apple Silicon 和 Intel 的 SMC Key 集合不同，必须枚举发现而非硬编码

### 重构方案（vs 常规做法）

| 维度 | 常规做法 | 本方案 |
|------|---------|--------|
| 传感器列表 | 硬编码 3-5 个 Key | 运行时 SMC 枚举 + 用户自定义 |
| UI | 纯数值列表 | 渐变温度条 + 热力图，一眼看温差 |
| 架构 | 混入 SystemMonitor | 独立 TemperatureMonitor，零侵入 |
| 可发现性 | 用户不知道还有哪些传感器 | 「+ 添加」列出所有可用传感器 |

---

## 二、功能目标

为 PowerPulse 新增**温度传感器监控**功能，以独立 Tab 形式呈现：

- **默认传感器**：CPU (TC0P)、GPU (TG0P)、电池 (TB0T)
- **可视化**：绿→黄→红渐变温度条 + 热力图矩阵
- **自定义管理**：用户可通过管理模式启停/排序传感器
- **零侵入**：不修改现有 BatteryMonitor / SystemMonitor / PowerHistoryStore 的任何代码

---

## 三、架构设计

```
PowerPulse/
├── ChargeWatchApp.swift          # [修改] AppDelegate 新增 TemperatureMonitor 持有
├── TemperatureMonitor.swift      # [新增] SMC 数据采集 + 平滑
├── SensorCatalogStore.swift      # [新增] 用户自定义传感器配置持久化
├── TemperatureTabView.swift      # [新增] 温度 Tab UI（温度条 + 热力图 + 管理模式）
├── LivePanelView.swift           # [修改] 新增第 5 个 Tab：「🌡 温度」
└── Models.swift                  # [修改] 新增 TemperatureSample 模型
```

### 数据流

```
AppleSMC (IOService)
  │  IOKit SMC Key 读取 (2s 间隔)
  ▼
TemperatureMonitor (ObservableObject)
  │  @Published sensors: [SensorReading]
  │  @Published history: [TemperatureSample] (150 样本, 5分钟)
  ▼
TemperatureTabView
  ├─ 温度条列表 (渐变条 + 数值)
  ├─ 热力图矩阵 (传感器 × 时间)
  └─ 管理模式 (齿轮进入, 拖拽 + 开关)
      │ 读写
      ▼
SensorCatalogStore → UserDefaults/JSON
```

### SMC 读取方案

```swift
// SMC Key 结构
struct SMCKey {
    let code: String    // "TC0P", "TG0P", "TB0T" 等
    let name: String    // "CPU Temperature", "GPU Temperature" 等
    let type: String    // "sp78" (2字节浮点) 或 "flt " (4字节浮点)
}

// 枚举可用 Key
func enumerateAvailableKeys() -> [SMCKey]
// 读取单个 Key 值
func readTemperature(key: SMCKey) -> Double?  // °C
```

SMC 通信基于标准 IOKit `IOConnectCallStructMethod`，通过 `AppleSMC` 服务的 `kSMCUserClientOpen` / `kSMCUserClientClose` / `kSMCHandleYPCEvent` 序列进行。

---

## 四、数据模型

```swift
// Models.swift 新增
struct TemperatureSample: Identifiable, Codable {
    let id: UUID
    let timestamp: Date
    let sensorKey: String
    let temperature: Double    // °C
}

struct SensorReading {
    let key: String
    let name: String
    let temperature: Double
    let maxObserved: Double    // 本次运行期间最高值
}

// SensorCatalogStore 持久化模型
struct SensorCatalog: Codable {
    var enabledKeys: [String]        // 排序即展示顺序
    var hiddenKeys: [String]         // 已隐藏但可重新添加
}
```

---

## 五、UI 规格

### 日常模式

```
┌─ 🌡 温度传感器 ──────── ⚙ ─┐
│                              │
│ CPU  ██████████████░░░  58°  │
│ GPU  ███████████░░░░░  52°  │
│ 电池 ████████░░░░░░░░  36°  │
│                              │
│ ┌─ 温度热力图 · 最近5分钟 ─┐ │
│ │ CPU  ■■■■■■■■□□          │ │
│ │ GPU  ■■■■■■■□□□          │ │
│ │ 电池 ■■■□□□□□□□          │ │
│ └──────────────────────────┘ │
└──────────────────────────────┘
```

- 温度条：`linear-gradient(90deg, #4ade80, #fbbf24, #f87171)`
- 条宽 = `当前温度 / maxObserved`（首次运行使用传感器上限估算）
- 颜色圆点与现有功率流色调体系一致（CPU=红, GPU=紫, 电池=黄）

### 管理模式

- 点击齿轮 → 标题变为「编辑传感器」+ 右上「完成」按钮
- 每行：⠿ 拖拽手柄 | 名称 | 颜色圆点 | 开关
- 底部「+ 添加传感器」→ 弹出可用传感器列表（排除已启用的）
- 拖拽排序即时生效，开关立即应用，退出管理模式后界面刷新

### 热力图

- 每行一个传感器，每列一个采样时刻
- 颜色映射：该传感器自身的温度范围 → 蓝(低) → 绿 → 黄 → 红(高)
- 最右列为最新数据，自动滚动
- 高度随启用的传感器数量自适应

### 空状态

- SMC 枚举返回空：「当前设备无可用温度传感器」
- 用户关闭所有传感器：「暂无启用的传感器，点击齿轮添加」

---

## 六、与现有 Tab 的统一

LivePanelView 底部导航栏更新为：

```
⚡ 功率流 | 🖥 系统监控 | 🌡 温度 | 📊 历史 | ℹ️ 关于 | ⏻ 退出
```

温度 Tab 放在系统监控和历史之间，按"实时数据 → 历史记录 → 关于"的逻辑排列。

---

## 七、技术风险评估

| 风险 | 可能性 | 影响 | 缓解措施 |
|------|--------|------|---------|
| Apple Silicon SMC Key 集合与 Intel 不同 | 高 | 传感器发现不全 | 运行时枚举 + 降级到已知通用 Key |
| 部分 Key 返回非温度数据 | 中 | 崩溃或显示异常 | 类型校验 + try? 包裹 + 无效值过滤 |
| IOConnectCallStructMethod 权限拒绝 | 低 | 完全无法读取 | 降级提示用户授予辅助功能权限 |
| 大量传感器导致热力图性能问题 | 低 | 帧率下降 | 限制单次热力图绘制 ≤ 50 列 |

---

## 八、测试策略

| 层级 | 内容 |
|------|------|
| 单元测试 | SMC Key 编解码、MovingAverage 平滑、SensorCatalogStore 持久化 |
| 集成测试 | TemperatureMonitor 模拟数据注入、Tab 切换状态保持 |
| UI 测试 | 管理模式拖拽排序、开关即时刷新、空状态渲染 |
| 机型验证 | Intel Mac (TC0P/TG0P) vs Apple Silicon (pACC/MgCC/eACC) |

---

## 九、自审清单

- [x] 无 TBD / TODO 占位符
- [x] 架构与现有 MVVM + AppKit/SwiftUI 混合模式一致
- [x] 功能边界明确：不涉及风扇控制、不涉及告警通知
- [x] 数据采集 2 秒间隔与 SystemMonitor 一致，不增加额外功耗
- [x] 热力图仅在 Tab 可见时渲染（onAppear/onDisappear 控制）
- [x] 所有文件路径、类名、Key 名均为确定值
