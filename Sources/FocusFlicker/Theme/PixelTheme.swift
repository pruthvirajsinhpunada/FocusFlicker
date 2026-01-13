import SwiftUI

/// Retro pixel art theme configuration
struct PixelTheme {
    // MARK: - Colors
    
    /// Neon green for positive/healthy states
    static let neonGreen = Color(red: 0.2, green: 1.0, blue: 0.4)
    
    /// Electric cyan/blue for UI elements
    static let electricBlue = Color(red: 0.0, green: 0.9, blue: 1.0)
    
    /// Hot magenta/pink for accents
    static let hotPink = Color(red: 1.0, green: 0.2, blue: 0.6)
    
    /// Warning red for zombie mode
    static let dangerRed = Color(red: 1.0, green: 0.2, blue: 0.2)
    
    /// Warning yellow/orange
    static let warningYellow = Color(red: 1.0, green: 0.8, blue: 0.0)
    
    /// Deep purple background
    static let backgroundDark = Color(red: 0.08, green: 0.04, blue: 0.15)
    
    /// Slightly lighter purple for cards
    static let backgroundCard = Color(red: 0.12, green: 0.06, blue: 0.2)
    
    /// Grid line color
    static let gridLine = Color(red: 0.2, green: 0.1, blue: 0.3)
    
    // MARK: - Fonts
    
    /// Pixel-style font for headers (uses system monospace as fallback)
    static func pixelFont(size: CGFloat) -> Font {
        .system(size: size, weight: .bold, design: .monospaced)
    }
    
    /// Stats font
    static func statsFont(size: CGFloat) -> Font {
        .system(size: size, weight: .medium, design: .monospaced)
    }
}

// MARK: - Pixel Border Modifier

struct PixelBorder: ViewModifier {
    var color: Color = PixelTheme.electricBlue
    var cornerSize: CGFloat = 8
    
    func body(content: Content) -> some View {
        content
            .overlay(
                PixelBorderShape(cornerSize: cornerSize)
                    .stroke(color, lineWidth: 3)
            )
    }
}

struct PixelBorderShape: Shape {
    var cornerSize: CGFloat
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // Create a pixelated corner effect
        let cs = cornerSize
        
        // Top edge
        path.move(to: CGPoint(x: cs, y: 0))
        path.addLine(to: CGPoint(x: rect.width - cs, y: 0))
        
        // Top-right corner (stepped)
        path.addLine(to: CGPoint(x: rect.width - cs, y: cs/2))
        path.addLine(to: CGPoint(x: rect.width - cs/2, y: cs/2))
        path.addLine(to: CGPoint(x: rect.width - cs/2, y: cs))
        path.addLine(to: CGPoint(x: rect.width, y: cs))
        
        // Right edge
        path.addLine(to: CGPoint(x: rect.width, y: rect.height - cs))
        
        // Bottom-right corner (stepped)
        path.addLine(to: CGPoint(x: rect.width - cs/2, y: rect.height - cs))
        path.addLine(to: CGPoint(x: rect.width - cs/2, y: rect.height - cs/2))
        path.addLine(to: CGPoint(x: rect.width - cs, y: rect.height - cs/2))
        path.addLine(to: CGPoint(x: rect.width - cs, y: rect.height))
        
        // Bottom edge
        path.addLine(to: CGPoint(x: cs, y: rect.height))
        
        // Bottom-left corner (stepped)
        path.addLine(to: CGPoint(x: cs, y: rect.height - cs/2))
        path.addLine(to: CGPoint(x: cs/2, y: rect.height - cs/2))
        path.addLine(to: CGPoint(x: cs/2, y: rect.height - cs))
        path.addLine(to: CGPoint(x: 0, y: rect.height - cs))
        
        // Left edge
        path.addLine(to: CGPoint(x: 0, y: cs))
        
        // Top-left corner (stepped)
        path.addLine(to: CGPoint(x: cs/2, y: cs))
        path.addLine(to: CGPoint(x: cs/2, y: cs/2))
        path.addLine(to: CGPoint(x: cs, y: cs/2))
        path.closeSubpath()
        
        return path
    }
}

extension View {
    func pixelBorder(color: Color = PixelTheme.electricBlue) -> some View {
        modifier(PixelBorder(color: color))
    }
}

// MARK: - Scanline Overlay

struct ScanlineOverlay: View {
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 2) {
                ForEach(0..<Int(geometry.size.height / 4), id: \.self) { _ in
                    Rectangle()
                        .fill(Color.black.opacity(0.15))
                        .frame(height: 1)
                    Spacer()
                        .frame(height: 3)
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Pixel Health Bar

struct PixelHealthBar: View {
    var value: Double  // 0.0 to 1.0
    var maxSegments: Int = 10
    var segmentColor: Color = PixelTheme.neonGreen
    var emptyColor: Color = PixelTheme.gridLine
    var label: String = "FOCUS METER"
    
    private var filledSegments: Int {
        Int(value * Double(maxSegments))
    }
    
    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(PixelTheme.pixelFont(size: 12))
                .foregroundColor(PixelTheme.electricBlue)
            
            HStack(spacing: 4) {
                ForEach(0..<maxSegments, id: \.self) { index in
                    Rectangle()
                        .fill(index < filledSegments ? segmentColor : emptyColor)
                        .frame(height: 20)
                        .overlay(
                            Rectangle()
                                .stroke(Color.black, lineWidth: 1)
                        )
                }
            }
            .padding(4)
            .background(Color.black.opacity(0.5))
            .pixelBorder(color: segmentColor.opacity(0.5))
        }
    }
}

// MARK: - Pixel Eye Sprite

struct PixelEyeSprite: View {
    var isBlinking: Bool = false
    var zombieMode: Bool = false
    
    @State private var glowAnimation = false
    
    var eyeColor: Color {
        zombieMode ? PixelTheme.dangerRed : PixelTheme.electricBlue
    }
    
    var body: some View {
        ZStack {
            // Glow effect
            Circle()
                .fill(
                    RadialGradient(
                        colors: [eyeColor.opacity(0.4), .clear],
                        center: .center,
                        startRadius: 30,
                        endRadius: 80
                    )
                )
                .frame(width: 160, height: 160)
                .scaleEffect(glowAnimation ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: glowAnimation)
            
            // Eye shape (pixelated look)
            ZStack {
                // Outer eye shape
                Ellipse()
                    .fill(Color.white)
                    .frame(width: 100, height: isBlinking ? 10 : 60)
                    .overlay(
                        Ellipse()
                            .stroke(eyeColor, lineWidth: 4)
                    )
                
                if !isBlinking {
                    // Iris
                    Circle()
                        .fill(eyeColor)
                        .frame(width: 35, height: 35)
                    
                    // Pupil
                    Circle()
                        .fill(Color.black)
                        .frame(width: 18, height: 18)
                    
                    // Highlight
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .offset(x: -5, y: -5)
                }
            }
            
            // Zombie mode red overlay
            if zombieMode {
                Circle()
                    .fill(PixelTheme.dangerRed.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .blur(radius: 20)
            }
        }
        .onAppear {
            glowAnimation = true
        }
    }
}

// MARK: - Pixel Button

struct PixelButton: View {
    let title: String
    let icon: String?
    var color: Color = PixelTheme.electricBlue
    let action: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .bold))
                }
                Text(title.uppercased())
                    .font(PixelTheme.pixelFont(size: 14))
            }
            .foregroundColor(isPressed ? color : .white)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                ZStack {
                    // Shadow layer
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color.opacity(0.3))
                        .offset(y: isPressed ? 0 : 4)
                    
                    // Main button
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isPressed ? color.opacity(0.8) : color)
                        .offset(y: isPressed ? 2 : 0)
                }
            )
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Stat Display

struct PixelStatDisplay: View {
    let icon: String
    let label: String
    let value: String
    var color: Color = PixelTheme.electricBlue
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(color)
            
            Text(label.uppercased())
                .font(PixelTheme.statsFont(size: 10))
                .foregroundColor(color.opacity(0.7))
            
            Text(value)
                .font(PixelTheme.pixelFont(size: 18))
                .foregroundColor(.white)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(PixelTheme.backgroundCard)
        .pixelBorder(color: color.opacity(0.5))
    }
}

// MARK: - Level Badge

struct LevelBadge: View {
    let level: Int
    let title: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text("LEVEL \(level)")
                .font(PixelTheme.pixelFont(size: 16))
                .foregroundColor(PixelTheme.warningYellow)
            
            Text(title.uppercased())
                .font(PixelTheme.pixelFont(size: 24))
                .foregroundStyle(
                    LinearGradient(
                        colors: [PixelTheme.electricBlue, PixelTheme.hotPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
    }
}

// MARK: - Zombie Mode Banner

struct ZombieModeBanner: View {
    @State private var flashAnimation = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "skull.fill")
                .font(.system(size: 20))
            
            Text("ZOMBIE MODE")
                .font(PixelTheme.pixelFont(size: 20))
            
            Image(systemName: "skull.fill")
                .font(.system(size: 20))
        }
        .foregroundColor(.white)
        .padding(.horizontal, 24)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 4)
                .fill(PixelTheme.dangerRed)
                .opacity(flashAnimation ? 0.8 : 1.0)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
        )
        .shadow(color: PixelTheme.dangerRed.opacity(0.8), radius: 20)
        .onAppear {
            withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                flashAnimation = true
            }
        }
    }
}

// MARK: - Grid Background

struct PixelGridBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Base gradient
                LinearGradient(
                    colors: [
                        PixelTheme.backgroundDark,
                        Color(red: 0.05, green: 0.02, blue: 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                
                // Grid pattern
                Path { path in
                    let gridSize: CGFloat = 30
                    
                    // Vertical lines
                    for x in stride(from: 0, to: geometry.size.width, by: gridSize) {
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))
                    }
                    
                    // Horizontal lines
                    for y in stride(from: 0, to: geometry.size.height, by: gridSize) {
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(PixelTheme.gridLine.opacity(0.3), lineWidth: 1)
                
                // Vignette effect
                RadialGradient(
                    colors: [.clear, Color.black.opacity(0.6)],
                    center: .center,
                    startRadius: geometry.size.width * 0.3,
                    endRadius: geometry.size.width * 0.8
                )
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - Corner Decorations

struct PixelCornerDecorations: View {
    var color: Color = PixelTheme.hotPink
    
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Top-left corner
                CornerDecoration()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .position(x: 25, y: 60)
                
                // Top-right corner
                CornerDecoration()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(90))
                    .position(x: geometry.size.width - 25, y: 60)
                
                // Bottom-left corner
                CornerDecoration()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(-90))
                    .position(x: 25, y: geometry.size.height - 60)
                
                // Bottom-right corner
                CornerDecoration()
                    .stroke(color, lineWidth: 2)
                    .frame(width: 40, height: 40)
                    .rotationEffect(.degrees(180))
                    .position(x: geometry.size.width - 25, y: geometry.size.height - 60)
            }
        }
        .allowsHitTesting(false)
    }
}

struct CornerDecoration: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        // L-shaped corner with pixel details
        path.move(to: CGPoint(x: 0, y: rect.height))
        path.addLine(to: CGPoint(x: 0, y: 0))
        path.addLine(to: CGPoint(x: rect.width, y: 0))
        
        // Add pixel details
        path.move(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.3))
        path.addLine(to: CGPoint(x: rect.width * 0.3, y: rect.height * 0.5))
        path.addLine(to: CGPoint(x: rect.width * 0.5, y: rect.height * 0.5))
        
        return path
    }
}

// MARK: - Previews

#Preview("Health Bar") {
    ZStack {
        PixelGridBackground()
        PixelHealthBar(value: 0.7)
            .padding()
    }
}

#Preview("Eye Sprite") {
    ZStack {
        PixelGridBackground()
        VStack(spacing: 40) {
            PixelEyeSprite(isBlinking: false, zombieMode: false)
            PixelEyeSprite(isBlinking: false, zombieMode: true)
        }
    }
}

#Preview("Components") {
    ZStack {
        PixelGridBackground()
        VStack(spacing: 20) {
            LevelBadge(level: 5, title: "Focus Warrior")
            
            HStack {
                PixelStatDisplay(icon: "eye", label: "Blinks", value: "15/min")
                PixelStatDisplay(icon: "clock", label: "Stare", value: "00:45", color: PixelTheme.warningYellow)
            }
            .padding(.horizontal)
            
            ZombieModeBanner()
            
            HStack {
                PixelButton(title: "Pause", icon: "pause.fill", color: PixelTheme.warningYellow) {}
                PixelButton(title: "Retry", icon: "arrow.clockwise", color: PixelTheme.neonGreen) {}
            }
        }
    }
}
