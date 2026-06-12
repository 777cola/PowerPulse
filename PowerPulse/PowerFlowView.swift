import SwiftUI

// MARK: - Power Flow Animation View

struct PowerFlowView: View {
    let flowData: PowerFlowData
    @State private var animationPhase: CGFloat = 0
    @State private var flowOpacity: Double = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Title bar
            headerBar
            
            // Main flow container
            flowContainer
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                flowOpacity = 1
            }
            withAnimation(.linear(duration: 2.0).repeatForever(autoreverses: false)) {
                animationPhase = 1
            }
        }
    }
    
    // MARK: - Header
    
    private var headerBar: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "bolt.horizontal.fill")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                Text("功率流")
                    .font(.system(size: 13, weight: .medium))
            }
            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }
    
    // MARK: - Flow Container
    
    private var flowContainer: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            
            if flowData.isPluggedIn {
                pluggedInFlow(width: w, height: h)
            } else {
                batteryFlow(width: w, height: h)
            }
        }
        .frame(height: 160)
        .opacity(flowOpacity)
    }
    
    // MARK: - Plugged In Flow (Wall → System + Battery)
    
    private func pluggedInFlow(width: CGFloat, height: CGFloat) -> some View {
        let sysW = max(flowData.systemUsage, 0.1)
        let batW = max(flowData.batteryChargeRate, 0.1)
        let total = max(flowData.wallPower, sysW + batW, 1)
        
        let sysRatio = CGFloat(sysW / total)
        let batRatio = CGFloat(batW / total)
        
        // Vertical positions: system top band, battery bottom band
        let gap: CGFloat = 8
        let maxBandHeight = height * 0.45
        let bandAreaHeight = (height - gap) / 2
        let sysBandHeight = max(bandAreaHeight * sysRatio, 8)
        let batBandHeight = max(bandAreaHeight * batRatio, 8)
        
        // 左侧源方块高度 = 两条流带的总高度
        let sourceHeight = sysBandHeight + batBandHeight + gap
        
        return ZStack {
            // Source block (left) - Wall Power
            sourceBlock(x: 0, height: height, watts: flowData.wallPower, icon: "bolt.fill", color: .primary, bandHeight: sourceHeight)
            
            // System flow (top band) - horizontal with slight curve
            HorizontalFlowBand(
                startX: 55, endX: width - 55,
                centerY: bandAreaHeight / 2,
                bandHeight: sysBandHeight,
                animationPhase: animationPhase,
                color: .blue,
                glowColor: .blue.opacity(0.2)
            )
            
            // System label (right)
            flowEndIcon(x: width - 25, y: bandAreaHeight / 2, icon: "desktopcomputer", label: "系统", watts: sysW, color: .blue)
            
            // Battery flow (bottom band) - horizontal
            if flowData.isCharging && batW > 0.1 {
                HorizontalFlowBand(
                    startX: 55, endX: width - 55,
                    centerY: bandAreaHeight + gap + bandAreaHeight / 2,
                    bandHeight: batBandHeight,
                    animationPhase: animationPhase,
                    color: .green,
                    glowColor: .green.opacity(0.2)
                )
                
                // Battery label (right)
                flowEndIcon(x: width - 25, y: bandAreaHeight + gap + bandAreaHeight / 2, icon: "battery.100.bolt", label: "充电", watts: batW, color: .green)
            }
            
            // Center watt labels on bands
            if sysW > 0.5 {
                Text(String(format: "%.1fW", sysW))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.blue.opacity(0.7)))
                    .position(x: (55 + width - 55) / 2, y: bandAreaHeight / 2)
            }
            
            if flowData.isCharging && batW > 0.5 {
                Text(String(format: "%.1fW", batW))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color.green.opacity(0.7)))
                    .position(x: (55 + width - 55) / 2, y: bandAreaHeight + gap + bandAreaHeight / 2)
            }
        }
    }
    
    // MARK: - Battery Only Flow (Battery → System) — Simple Horizontal Band
    
    private func batteryFlow(width: CGFloat, height: CGFloat) -> some View {
        let batW = max(flowData.batteryRate, 0.1)
        let centerY = height / 2
        // 流带高度与功率成比例（最大功率约100W对应最大高度）
        let maxBandHeight: CGFloat = height * 0.6
        let bandHeight: CGFloat = max(maxBandHeight * CGFloat(min(batW / 60.0, 1.0)), 12)
        
        return ZStack {
            // Source: Battery (left) — 高度与流带一致
            sourceBlock(x: 0, height: height, watts: batW, icon: "battery.100", color: .orange, bandHeight: bandHeight)
            
            // Simple horizontal animated band from battery to system
            HorizontalFlowBand(
                startX: 50, endX: width - 50,
                centerY: centerY,
                bandHeight: bandHeight,
                animationPhase: animationPhase,
                color: .orange,
                glowColor: .orange.opacity(0.2)
            )
            
            // Center watt label
            if batW > 0.5 {
                Text(String(format: "%.1fW", batW))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.orange.opacity(0.8)))
                    .position(x: (50 + width - 50) / 2, y: centerY)
            }
            
            // System icon (right)
            flowEndIcon(x: width - 25, y: centerY, icon: "desktopcomputer", label: "系统", watts: batW, color: .orange)
        }
    }
    
    // MARK: - Source Block
    
    private func sourceBlock(x: CGFloat, height: CGFloat, watts: Double, icon: String, color: Color, bandHeight: CGFloat? = nil) -> some View {
        let innerHeight = bandHeight ?? height
        return VStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(String(format: "%.0fW", watts))
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(width: 46, height: innerHeight)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.15))
        )
        .position(x: x + 23, y: height / 2)
    }
    
    // MARK: - Flow End Icon
    
    private func flowEndIcon(x: CGFloat, y: CGFloat, icon: String, label: String, watts: Double, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .position(x: x, y: y)
    }
}

// MARK: - Horizontal Flow Band (Animated)

struct HorizontalFlowBand: View {
    let startX: CGFloat
    let endX: CGFloat
    let centerY: CGFloat
    let bandHeight: CGFloat
    let animationPhase: CGFloat
    let color: Color
    let glowColor: Color
    
    var body: some View {
        ZStack {
            // Glow effect behind the band
            HorizontalBandShape(
                startX: startX, endX: endX,
                centerY: centerY,
                bandHeight: bandHeight + 6
            )
            .fill(glowColor)
            .blur(radius: 4)
            
            // Main band
            HorizontalBandShape(
                startX: startX, endX: endX,
                centerY: centerY,
                bandHeight: bandHeight
            )
            .fill(
                LinearGradient(
                    colors: [color.opacity(0.15), color.opacity(0.35), color.opacity(0.15)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            
            // Border
            HorizontalBandShape(
                startX: startX, endX: endX,
                centerY: centerY,
                bandHeight: bandHeight
            )
            .stroke(color.opacity(0.3), lineWidth: 0.5)
            
            // Animated dots flowing along the band
            HorizontalFlowDots(
                startX: startX, endX: endX,
                centerY: centerY,
                phase: animationPhase,
                color: color,
                dotCount: 8
            )
            
            // Animated gradient overlay moving from left to right
            AnimatedGradientOverlay(
                startX: startX, endX: endX,
                centerY: centerY,
                bandHeight: bandHeight,
                phase: animationPhase,
                color: color
            )
        }
    }
}

// MARK: - Horizontal Band Shape

struct HorizontalBandShape: Shape {
    let startX: CGFloat
    let endX: CGFloat
    let centerY: CGFloat
    let bandHeight: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let halfH = bandHeight / 2
        let midX = (startX + endX) / 2
        
        // Top edge with gentle curve
        path.move(to: CGPoint(x: startX, y: centerY - halfH))
        path.addQuadCurve(
            to: CGPoint(x: endX, y: centerY - halfH),
            control: CGPoint(x: midX, y: centerY - halfH - 2)
        )
        
        // Right cap
        path.addQuadCurve(
            to: CGPoint(x: endX, y: centerY + halfH),
            control: CGPoint(x: endX + 3, y: centerY)
        )
        
        // Bottom edge with gentle curve
        path.addQuadCurve(
            to: CGPoint(x: startX, y: centerY + halfH),
            control: CGPoint(x: midX, y: centerY + halfH + 2)
        )
        
        // Left cap
        path.addQuadCurve(
            to: CGPoint(x: startX, y: centerY - halfH),
            control: CGPoint(x: startX - 3, y: centerY)
        )
        
        path.closeSubpath()
        return path
    }
}

// MARK: - Horizontal Flow Dots

struct HorizontalFlowDots: View {
    let startX: CGFloat
    let endX: CGFloat
    let centerY: CGFloat
    let phase: CGFloat
    let color: Color
    let dotCount: Int
    
    var body: some View {
        ForEach(0..<dotCount, id: \.self) { i in
            let t = (CGFloat(i) / CGFloat(dotCount) + phase).truncatingRemainder(dividingBy: 1.0)
            let x = startX + (endX - startX) * t
            // Slight vertical wobble
            let yOffset = sin(t * .pi * 2) * 2
            let opacity = sin(t * .pi) * 0.7 + 0.1
            let dotSize = 3.0 + sin(t * .pi) * 1.5
            
            Circle()
                .fill(color.opacity(opacity))
                .frame(width: dotSize, height: dotSize)
                .position(x: x, y: centerY + yOffset)
        }
    }
}

// MARK: - Animated Gradient Overlay

struct AnimatedGradientOverlay: View {
    let startX: CGFloat
    let endX: CGFloat
    let centerY: CGFloat
    let bandHeight: CGFloat
    let phase: CGFloat
    let color: Color
    
    var body: some View {
        let bandWidth = endX - startX
        // The highlight position moves from left to right
        let highlightX = startX + bandWidth * phase
        
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [
                        color.opacity(0),
                        color.opacity(0.12),
                        color.opacity(0)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(width: bandWidth * 0.3, height: bandHeight)
            .position(x: highlightX, y: centerY)
            .mask(
                HorizontalBandShape(
                    startX: startX, endX: endX,
                    centerY: centerY,
                    bandHeight: bandHeight
                )
            )
    }
}

// MARK: - Power Metric Card

struct PowerMetricCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.gray.opacity(0.08))
        )
    }
}
