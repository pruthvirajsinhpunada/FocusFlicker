import SwiftUI

/// Pixel-themed onboarding view for first-time users
struct OnboardingView: View {
    @ObservedObject var appState: AppState
    @ObservedObject var eyeTracker: EyeTrackingManager
    @ObservedObject var motionManager: MotionResetManager
    
    @State private var currentPage = 0
    @State private var cameraGranted = false
    @State private var motionGranted = false
    
    var body: some View {
        ZStack {
            // Pixel grid background
            PixelGridBackground()
            
            // Corner decorations
            PixelCornerDecorations(color: PixelTheme.hotPink)
            
            // Scanlines
            ScanlineOverlay()
            
            VStack(spacing: 0) {
                // Page content
                TabView(selection: $currentPage) {
                    PixelWelcomePage()
                        .tag(0)
                    
                    PixelHowItWorksPage()
                        .tag(1)
                    
                    PixelCameraPermissionPage(
                        isGranted: cameraGranted,
                        onRequest: requestCameraPermission
                    )
                    .tag(2)
                    
                    PixelMotionPermissionPage(
                        isGranted: motionGranted,
                        onRequest: requestMotionPermission
                    )
                    .tag(3)
                    
                    PixelResetDemoPage(motionManager: motionManager)
                        .tag(4)
                    
                    PixelGetStartedPage(onComplete: completeOnboarding)
                        .tag(5)
                }
                #if os(iOS)
                .tabViewStyle(.page(indexDisplayMode: .never))
                #endif
                
                // Pixel page indicator
                HStack(spacing: 8) {
                    ForEach(0..<6, id: \.self) { index in
                        Rectangle()
                            .fill(index == currentPage ? PixelTheme.electricBlue : PixelTheme.gridLine)
                            .frame(width: index == currentPage ? 24 : 12, height: 8)
                            .animation(.spring(duration: 0.3), value: currentPage)
                    }
                }
                .padding(.bottom, 20)
                
                // Navigation buttons
                HStack {
                    if currentPage > 0 {
                        PixelButton(title: "Back", icon: "chevron.left", color: PixelTheme.gridLine) {
                            withAnimation {
                                currentPage -= 1
                            }
                        }
                    }
                    
                    Spacer()
                    
                    if currentPage < 5 {
                        PixelButton(
                            title: "Next",
                            icon: "chevron.right",
                            color: canAdvance ? PixelTheme.electricBlue : PixelTheme.gridLine
                        ) {
                            if canAdvance {
                                withAnimation {
                                    currentPage += 1
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
    }
    
    private var canAdvance: Bool {
        switch currentPage {
        case 2: return cameraGranted
        case 3: return motionGranted
        default: return true
        }
    }
    
    private func requestCameraPermission() {
        Task {
            cameraGranted = await eyeTracker.requestCameraPermission()
        }
    }
    
    private func requestMotionPermission() {
        Task {
            motionGranted = await motionManager.requestMotionPermission()
        }
    }
    
    private func completeOnboarding() {
        appState.completeOnboarding()
    }
}

// MARK: - Pixel Onboarding Pages

struct PixelWelcomePage: View {
    @State private var eyeAnimation = false
    
    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            
            // Animated pixel eye
            PixelEyeSprite(isBlinking: eyeAnimation, zombieMode: false)
                .onAppear {
                    // Blink animation loop
                    Timer.scheduledTimer(withTimeInterval: 3.0, repeats: true) { _ in
                        eyeAnimation = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                            eyeAnimation = false
                        }
                    }
                }
            
            Text("FOCUS FLICKER")
                .font(PixelTheme.pixelFont(size: 32))
                .foregroundStyle(
                    LinearGradient(
                        colors: [PixelTheme.electricBlue, PixelTheme.hotPink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            
            Text("THE ANTI-DISTRACTION SHIELD")
                .font(PixelTheme.statsFont(size: 14))
                .foregroundColor(PixelTheme.warningYellow)
            
            Spacer()
            
            Text("PRESS START TO BEGIN")
                .font(PixelTheme.statsFont(size: 12))
                .foregroundColor(.white.opacity(0.5))
                .opacity(eyeAnimation ? 0.3 : 1.0)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: eyeAnimation)
            
            Spacer()
        }
    }
}

struct PixelHowItWorksPage: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Text("HOW TO PLAY")
                .font(PixelTheme.pixelFont(size: 24))
                .foregroundColor(PixelTheme.electricBlue)
            
            VStack(alignment: .leading, spacing: 24) {
                PixelFeatureRow(
                    icon: "eye",
                    title: "TRACK",
                    description: "We monitor your blink rate",
                    color: PixelTheme.neonGreen
                )
                
                PixelFeatureRow(
                    icon: "exclamationmark.triangle",
                    title: "DETECT",
                    description: "Screen dims when you zone out",
                    color: PixelTheme.warningYellow
                )
                
                PixelFeatureRow(
                    icon: "figure.walk",
                    title: "RESET",
                    description: "Stand & move to unlock colors",
                    color: PixelTheme.hotPink
                )
            }
            .padding(.horizontal, 24)
            
            Spacer()
        }
    }
}

struct PixelFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    var color: Color = PixelTheme.electricBlue
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon box
            ZStack {
                Rectangle()
                    .fill(color.opacity(0.2))
                    .frame(width: 50, height: 50)
                    .overlay(
                        Rectangle()
                            .stroke(color, lineWidth: 2)
                    )
                
                Image(systemName: icon)
                    .font(.system(size: 22))
                    .foregroundColor(color)
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(PixelTheme.pixelFont(size: 16))
                    .foregroundColor(color)
                
                Text(description.uppercased())
                    .font(PixelTheme.statsFont(size: 11))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
    }
}

struct PixelCameraPermissionPage: View {
    let isGranted: Bool
    let onRequest: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Camera icon
            ZStack {
                Rectangle()
                    .fill(isGranted ? PixelTheme.neonGreen.opacity(0.2) : PixelTheme.electricBlue.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Rectangle()
                            .stroke(isGranted ? PixelTheme.neonGreen : PixelTheme.electricBlue, lineWidth: 3)
                    )
                
                Image(systemName: isGranted ? "checkmark" : "camera.fill")
                    .font(.system(size: 40))
                    .foregroundColor(isGranted ? PixelTheme.neonGreen : PixelTheme.electricBlue)
            }
            
            Text("CAMERA ACCESS")
                .font(PixelTheme.pixelFont(size: 22))
                .foregroundColor(.white)
            
            Text("REQUIRED FOR EYE TRACKING")
                .font(PixelTheme.statsFont(size: 12))
                .foregroundColor(.white.opacity(0.6))
            
            if !isGranted {
                PixelButton(title: "Enable", icon: "camera.fill", color: PixelTheme.electricBlue, action: onRequest)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("UNLOCKED")
                }
                .font(PixelTheme.pixelFont(size: 16))
                .foregroundColor(PixelTheme.neonGreen)
            }
            
            Spacer()
        }
    }
}

struct PixelMotionPermissionPage: View {
    let isGranted: Bool
    let onRequest: () -> Void
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Gyroscope icon
            ZStack {
                Rectangle()
                    .fill(isGranted ? PixelTheme.neonGreen.opacity(0.2) : PixelTheme.hotPink.opacity(0.2))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Rectangle()
                            .stroke(isGranted ? PixelTheme.neonGreen : PixelTheme.hotPink, lineWidth: 3)
                    )
                
                Image(systemName: isGranted ? "checkmark" : "gyroscope")
                    .font(.system(size: 40))
                    .foregroundColor(isGranted ? PixelTheme.neonGreen : PixelTheme.hotPink)
            }
            
            Text("MOTION ACCESS")
                .font(PixelTheme.pixelFont(size: 22))
                .foregroundColor(.white)
            
            Text("DETECTS PHYSICAL MOVEMENT")
                .font(PixelTheme.statsFont(size: 12))
                .foregroundColor(.white.opacity(0.6))
            
            if !isGranted {
                PixelButton(title: "Enable", icon: "gyroscope", color: PixelTheme.hotPink, action: onRequest)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("UNLOCKED")
                }
                .font(PixelTheme.pixelFont(size: 16))
                .foregroundColor(PixelTheme.neonGreen)
            }
            
            Spacer()
        }
    }
}

struct PixelResetDemoPage: View {
    @ObservedObject var motionManager: MotionResetManager
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            Text("PRACTICE MODE")
                .font(PixelTheme.pixelFont(size: 24))
                .foregroundColor(PixelTheme.warningYellow)
            
            Text("LEARN THE RESET COMBO")
                .font(PixelTheme.statsFont(size: 12))
                .foregroundColor(.white.opacity(0.6))
            
            // Demo steps
            VStack(spacing: 20) {
                PixelDemoStep(number: 1, title: "STAND UP", icon: "figure.stand")
                PixelDemoStep(number: 2, title: "WAVE PHONE", icon: "arrow.triangle.2.circlepath")
            }
            .padding(.vertical, 24)
            
            // Try button
            PixelButton(title: "Try Now", icon: "gamecontroller.fill", color: PixelTheme.hotPink) {
                motionManager.startMonitoring()
                motionManager.beginResetAttempt()
            }
            
            // Progress feedback
            if motionManager.resetPhase != .idle {
                VStack(spacing: 12) {
                    PixelHealthBar(
                        value: motionManager.resetProgress,
                        maxSegments: 8,
                        segmentColor: PixelTheme.neonGreen,
                        label: "COMBO PROGRESS"
                    )
                    .frame(width: 200)
                    
                    Text(motionManager.resetPhase.instruction.uppercased())
                        .font(PixelTheme.statsFont(size: 11))
                        .foregroundColor(PixelTheme.electricBlue)
                }
                .padding(.top, 16)
            }
            
            Spacer()
        }
    }
}

struct PixelDemoStep: View {
    let number: Int
    let title: String
    let icon: String
    
    var body: some View {
        HStack(spacing: 16) {
            // Step number
            ZStack {
                Rectangle()
                    .fill(PixelTheme.electricBlue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Rectangle()
                            .stroke(PixelTheme.electricBlue, lineWidth: 2)
                    )
                
                Text("\(number)")
                    .font(PixelTheme.pixelFont(size: 20))
                    .foregroundColor(PixelTheme.electricBlue)
            }
            
            HStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(PixelTheme.hotPink)
                
                Text(title)
                    .font(PixelTheme.pixelFont(size: 14))
                    .foregroundColor(.white)
            }
            
            Spacer()
        }
        .padding(.horizontal, 40)
    }
}

struct PixelGetStartedPage: View {
    let onComplete: () -> Void
    
    @State private var sparkleAnimation = false
    
    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            
            // Trophy/star animation
            ZStack {
                // Glow
                Circle()
                    .fill(PixelTheme.warningYellow.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .scaleEffect(sparkleAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: sparkleAnimation)
                
                Image(systemName: "star.fill")
                    .font(.system(size: 60))
                    .foregroundColor(PixelTheme.warningYellow)
            }
            .onAppear { sparkleAnimation = true }
            
            Text("READY TO PLAY!")
                .font(PixelTheme.pixelFont(size: 28))
                .foregroundColor(PixelTheme.neonGreen)
            
            Text("MAINTAIN FOCUS TO EARN XP")
                .font(PixelTheme.statsFont(size: 12))
                .foregroundColor(.white.opacity(0.6))
            
            Spacer()
            
            PixelButton(title: "Start Game", icon: "play.fill", color: PixelTheme.neonGreen, action: onComplete)
            
            Spacer()
        }
    }
}

#Preview {
    OnboardingView(
        appState: AppState(),
        eyeTracker: EyeTrackingManager(),
        motionManager: MotionResetManager()
    )
}
