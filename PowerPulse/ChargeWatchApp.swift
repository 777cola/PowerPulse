import SwiftUI
import AppKit

@main
struct ChargeWatchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings { EmptyView() }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var eventMonitor: Any?
    
    let batteryMonitor = BatteryMonitor()
    let historyStore = PowerHistoryStore()
    let systemMonitor = SystemMonitor()
    
    private var statusBarTimer: Timer?
    private var wasPluggedIn: Bool = false
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        setupStatusItem()
        setupPopover()
        startMonitoring()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem.button {
            updateStatusBarTitle()
            button.action = #selector(togglePopover)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }
    
    private func updateStatusBarTitle() {
        guard let button = statusItem.button else { return }
        
        let flow = batteryMonitor.smoothedData
        let percent = batteryMonitor.batteryPercent
        
        // 颜色编码
        let color: NSColor
        let showBolt: Bool
        
        if flow.isCharging {
            color = .systemGreen
            showBolt = true
        } else if flow.isPluggedIn {
            color = .systemPurple
            showBolt = false
        } else {
            showBolt = false
            color = percent < 15 ? .systemRed : .white
        }
        
        // 功率值
        let watts: Double
        if flow.isPluggedIn {
            watts = flow.wallPower
        } else {
            watts = flow.systemUsage
        }
        
        // 电池图标（纯图标，不含文字）
        let batteryImage = createBatteryIcon(percent: percent, color: color, showBolt: showBolt)
        batteryImage.isTemplate = false
        
        // 布局：[百分比] [电池图标] [瓦数]
        let attrString = NSMutableAttributedString()
        
        // 左：百分比
        let percentText = String(format: "%d%%", percent)
        let percentAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        attrString.append(NSAttributedString(string: percentText, attributes: percentAttrs))
        
        // 中：电池图标（间距稍大）
        let leftSpacer = NSAttributedString(string: " ", attributes: [.font: NSFont.systemFont(ofSize: 5)])
        let rightSpacer = NSAttributedString(string: " ", attributes: [.font: NSFont.systemFont(ofSize: 3)])
        attrString.append(leftSpacer)
        let iconAttachment = NSTextAttachment()
        iconAttachment.image = batteryImage
        attrString.append(NSAttributedString(attachment: iconAttachment))
        attrString.append(rightSpacer)
        
        // 右：瓦数
        let wattsText = String(format: "%.0fW", watts)
        let wattsAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .semibold),
            .foregroundColor: NSColor.labelColor
        ]
        attrString.append(NSAttributedString(string: wattsText, attributes: wattsAttrs))
        
        button.attributedTitle = attrString
    }
    
    /// 电池图标：圆润风格 + Apple 方向闪电
    private func createBatteryIcon(percent: Int, color: NSColor, showBolt: Bool) -> NSImage {
        let width: CGFloat = 26
        let height: CGFloat = 13
        let batteryBodyWidth: CGFloat = 22
        let tipWidth: CGFloat = 2.5
        let tipHeight: CGFloat = 5.5
        let cornerRadius: CGFloat = 3
        let lineWidth: CGFloat = 0.9
        let inset: CGFloat = 1.5
        
        let image = NSImage(size: NSSize(width: width, height: height), flipped: false) { rect in
            let ctx = NSGraphicsContext.current!.cgContext
            
            // 轮廓（圆角）
            let bodyRect = CGRect(x: 0, y: 0, width: batteryBodyWidth, height: height)
            let bodyPath = CGPath(roundedRect: bodyRect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
            ctx.setStrokeColor(color.cgColor)
            ctx.setLineWidth(lineWidth)
            ctx.addPath(bodyPath)
            ctx.strokePath()
            
            // 正极小凸起（圆角）
            let tipX = batteryBodyWidth + 0.5
            let tipY = (height - tipHeight) / 2
            let tipRect = CGRect(x: tipX, y: tipY, width: tipWidth, height: tipHeight)
            let tipPath = CGPath(roundedRect: tipRect, cornerWidth: 1.2, cornerHeight: 1.2, transform: nil)
            ctx.setFillColor(color.cgColor)
            ctx.addPath(tipPath)
            ctx.fillPath()
            
            // 进度填充（圆角）
            let fillableWidth = batteryBodyWidth - inset * 2
            let fillWidth = fillableWidth * CGFloat(percent) / 100.0
            if fillWidth > 0 {
                let fillRect = CGRect(x: inset, y: inset, width: fillWidth, height: height - inset * 2)
                let fillPath = CGPath(roundedRect: fillRect, cornerWidth: 1.5, cornerHeight: 1.5, transform: nil)
                ctx.setFillColor(color.cgColor)
                ctx.addPath(fillPath)
                ctx.fillPath()
            }
            
            // 充电闪电（描边 zigzag，均匀粗细）
            if showBolt {
                ctx.saveGState()
                ctx.addPath(bodyPath)
                ctx.clip()
                
                ctx.setStrokeColor(NSColor.white.cgColor)
                ctx.setLineWidth(2.2)
                ctx.setLineCap(.round)
                ctx.setLineJoin(.round)
                
                let boltPath = CGMutablePath()
                // 尖锐 zigzag：左上→中右→中左→右下
                boltPath.move(to: CGPoint(x: 7.0, y: 1.5))
                boltPath.addLine(to: CGPoint(x: 14.0, y: 5.0))
                boltPath.addLine(to: CGPoint(x: 9.0, y: 5.8))
                boltPath.addLine(to: CGPoint(x: 15.5, y: 10.5))
                ctx.addPath(boltPath)
                ctx.strokePath()
                
                ctx.restoreGState()
            }
            
            return true
        }
        
        image.isTemplate = false
        return image
    }
    
    private func setupPopover() {
        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 420)
        popover.behavior = .transient
        popover.animates = true
        
        let contentView = LivePanelView(
            batteryMonitor: batteryMonitor,
            historyStore: historyStore,
            systemMonitor: systemMonitor
        )
        popover.contentViewController = NSHostingController(rootView: contentView)
        
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            if let popover = self?.popover, popover.isShown {
                popover.performClose(nil)
            }
        }
    }
    
    @objc func togglePopover() {
        guard let button = statusItem.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func startMonitoring() {
        batteryMonitor.start()
        systemMonitor.start()
        
        // Status bar update at 10-second interval
        statusBarTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.updateStatusBarTitle()
            
            let flow = self.batteryMonitor.flowData
            
            // 检测插电瞬间 → 重置充电历史
            if flow.isPluggedIn && !self.wasPluggedIn {
                self.historyStore.resetForNewChargingSession()
            }
            self.wasPluggedIn = flow.isPluggedIn
            
            // 记录充电样本
            if flow.isCharging && flow.batteryChargeRate > 0 {
                let sample = PowerSample(
                    timestamp: flow.timestamp,
                    watts: flow.batteryChargeRate,
                    batteryPercent: flow.batteryPercent,
                    isCharging: true
                )
                self.historyStore.addSample(sample)
            }
        }
        
        // Also do an initial status bar update after a short delay (for first data)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { [weak self] in
            self?.updateStatusBarTitle()
        }
    }
}
