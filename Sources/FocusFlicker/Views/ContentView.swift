import SwiftUI
import Combine

/// Main dashboard view with retro pixel game theme
struct ContentView: View {
    @StateObject private var appState = AppState()
    @StateObject private var eyeTracker = EyeTrackingManager()
    @StateObject private var motionManager = MotionResetManager()
    @StateObject private var feedbackController = ScreenFeedbackController()
    
    @State private var showSettings = false
    @State private var eyeBlinkAnimation = false
    
    // Gamification
    private var focusLevel: Int {
        let minutes = Int(appState.sessionStats.totalFocusTime / 60)
        return min(max(minutes / 5 + 1, 1), 99)  // Level up every 5 minutes
    }
    
    private var focusTitle: String {
        switch focusLevel {
        case 1...3: return "Rookie"
        case 4...6: return "Apprentice"
        case 7...10: return "Warrior"
        case 11...15: return "Champion"
        case 16...25: return "Master"
        default: return "Legend"
        }
    }
    
    var body: some View {
        ZStack {
            // Main content
            if !appState.hasCompletedOnboarding {
                OnboardingView(
                    appState: appState,
                    eyeTracker: eyeTracker,
                    motionManager: motionManager
                )
            } else {
                pixelDashboard
            }
            
            // Feedback overlay (always on top)
            PixelFeedbackOverlay(
                feedbackController: feedbackController,
                motionManager: motionManager
            )
        }
        .onReceive(eyeTracker.$currentMetrics) { metrics in
            appState.updateFocusLevel(from: metrics)
            
            // Trigger blink animation when eye openness changes
            if metrics.eyeOpenness < 0.3 {
                eyeBlinkAnimation = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    eyeBlinkAnimation = false
                }
            }
        }
        .onReceive(appState.$overlayIntensity) { intensity in
            if intensity > 0 {
                feedbackController.activate(intensity: intensity)
            } else {
                feedbackController.deactivate()
            }
        }
        .onReceive(motionManager.$resetPhase) { phase in
            appState.updateResetPhase(phase)
        }
        .onChange(of: appState.hasCompletedOnboarding) { _, completed in
            if completed {
                startTracking()
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(appState: appState)
        }
    }
    
    // MARK: - Pixel Dashboard
    
    private var pixelDashboard: some View {
        ZStack {
            // Pixel grid background
            PixelGridBackground()
            
            // Corner decorations
            PixelCornerDecorations()
            
            // Scanline overlay
            ScanlineOverlay()
            
            VStack(spacing: 0) {
                // Header
                pixelHeader
                
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        // Focus meter (health bar style)
                        PixelHealthBar(
                            value: focusProgress,
                            segmentColor: healthBarColor,
                            label: "FOCUS METER"
                        )
                        .padding(.horizontal)
                        
                        // Level badge
                        LevelBadge(level: focusLevel, title: focusTitle)
                        
                        // Eye sprite
                        PixelEyeSprite(
                            isBlinking: eyeBlinkAnimation,
                            zombieMode: appState.focusLevel == .zombie
                        )
                        .padding(.vertical, 10)
                        
                        // Zombie mode banner
                        if appState.focusLevel == .zombie {
                            ZombieModeBanner()
                                .transition(.scale.combined(with: .opacity))
                        }
                        
                        // Stats row
                        HStack(spacing: 12) {
                            PixelStatDisplay(
                                icon: "eye",
                                label: "Blinks",
                                value: "\(Int(appState.eyeMetrics.blinkRate))/min",
                                color: appState.eyeMetrics.isLowBlinkRate ? PixelTheme.dangerRed : PixelTheme.neonGreen
                            )
                            
                            PixelStatDisplay(
                                icon: "clock",
                                label: "Stare",
                                value: formatTime(appState.eyeMetrics.continuousStareTime),
                                color: appState.eyeMetrics.isExtendedStare ? PixelTheme.dangerRed : PixelTheme.electricBlue
                            )
                        }
                        .padding(.horizontal)
                        
                        // XP / Score display
                        xpDisplay
                        
                        // Control buttons
                        controlButtons
                            .padding(.top, 8)
                    }
                    .padding(.vertical)
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.focusLevel)
    }
    
    // MARK: - Header
    
    private var pixelHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("FOCUS FLICKER")
                    .font(PixelTheme.pixelFont(size: 18))
                    .foregroundColor(PixelTheme.electricBlue)
                
                HStack(spacing: 6) {
                    Circle()
                        .fill(appState.isTrackingActive ? PixelTheme.neonGreen : PixelTheme.dangerRed)
                        .frame(width: 8, height: 8)
                    
                    Text(appState.isTrackingActive ? "ONLINE" : "OFFLINE")
                        .font(PixelTheme.statsFont(size: 10))
                        .foregroundColor(.gray)
                }
            }
            
            Spacer()
            
            Button(action: { showSettings = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 22))
                    .foregroundColor(PixelTheme.hotPink)
            }
        }
        .padding()
        .background(Color.black.opacity(0.5))
    }
    
    // MARK: - Focus Progress
    
    private var focusProgress: Double {
        switch appState.focusLevel {
        case .focused: return 1.0
        case .warning: return 0.6
        case .zombie: return 0.2
        case .recovering: return motionManager.resetProgress
        }
    }
    
    private var healthBarColor: Color {
        switch appState.focusLevel {
        case .focused: return PixelTheme.neonGreen
        case .warning: return PixelTheme.warningYellow
        case .zombie: return PixelTheme.dangerRed
        case .recovering: return PixelTheme.electricBlue
        }
    }
    
    // MARK: - XP Display
    
    private var xpDisplay: some View {
        VStack(spacing: 8) {
            Text("SESSION SCORE")
                .font(PixelTheme.statsFont(size: 12))
                .foregroundColor(PixelTheme.electricBlue.opacity(0.7))
            
            HStack(alignment: .bottom, spacing: 4) {
                Text("\(Int(appState.sessionStats.totalFocusTime))")
                    .font(PixelTheme.pixelFont(size: 36))
                    .foregroundColor(PixelTheme.warningYellow)
                
                Text("XP")
                    .font(PixelTheme.pixelFont(size: 18))
                    .foregroundColor(PixelTheme.warningYellow.opacity(0.7))
                    .offset(y: -6)
            }
            
            // Resets as "lives lost"
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Image(systemName: index < (3 - min(appState.sessionStats.resetCount, 3)) ? "heart.fill" : "heart")
                        .foregroundColor(PixelTheme.dangerRed)
                        .font(.system(size: 16))
                }
                
                if appState.sessionStats.resetCount > 3 {
                    Text("+\(appState.sessionStats.resetCount - 3)")
                        .font(PixelTheme.statsFont(size: 12))
                        .foregroundColor(PixelTheme.dangerRed)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(PixelTheme.backgroundCard)
        .pixelBorder(color: PixelTheme.warningYellow.opacity(0.5))
        .padding(.horizontal)
    }
    
    // MARK: - Control Buttons
    
    private var controlButtons: some View {
        HStack(spacing: 16) {
            PixelButton(
                title: appState.isTrackingActive ? "Pause" : "Start",
                icon: appState.isTrackingActive ? "pause.fill" : "play.fill",
                color: appState.isTrackingActive ? PixelTheme.warningYellow : PixelTheme.neonGreen,
                action: toggleTracking
            )
            
            PixelButton(
                title: "Demo",
                icon: "exclamationmark.triangle.fill",
                color: PixelTheme.hotPink,
                action: triggerDemoOverlay
            )
        }
        .padding(.horizontal)
    }
    
    // MARK: - Helper Methods
    
    private func startTracking() {
        Task {
            let cameraGranted = await eyeTracker.requestCameraPermission()
            let motionGranted = await motionManager.requestMotionPermission()
            
            if cameraGranted {
                eyeTracker.startTracking()
            }
            
            if motionGranted {
                motionManager.startMonitoring()
            }
            
            await MainActor.run {
                appState.isTrackingActive = cameraGranted && motionGranted
            }
        }
    }
    
    private func toggleTracking() {
        if appState.isTrackingActive {
            eyeTracker.stopTracking()
            motionManager.stopMonitoring()
            appState.isTrackingActive = false
        } else {
            startTracking()
        }
    }
    
    private func triggerDemoOverlay() {
        appState.showOverlay = true
        feedbackController.activate(intensity: 0.7)
        motionManager.beginResetAttempt()
    }
    
    private func formatTime(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Pixel Feedback Overlay

struct PixelFeedbackOverlay: View {
    @ObservedObject var feedbackController: ScreenFeedbackController
    @ObservedObject var motionManager: MotionResetManager
    
    var body: some View {
        ZStack {
            // Dimming overlay
            Rectangle()
                .fill(Color.black.opacity(feedbackController.overlayOpacity))
                .ignoresSafeArea()
            
            // Desaturation layer
            Rectangle()
                .fill(Color.gray.opacity(feedbackController.desaturation * 0.3))
                .blendMode(.saturation)
                .ignoresSafeArea()
            
            // Recovery UI
            if feedbackController.isActive {
                VStack(spacing: 32) {
                    Spacer()
                    
                    // Skull icon
                    Image(systemName: "skull.fill")
                        .font(.system(size: 60))
                        .foregroundColor(PixelTheme.dangerRed)
                        .shadow(color: PixelTheme.dangerRed, radius: 20)
                    
                    Text("GAME OVER?")
                        .font(PixelTheme.pixelFont(size: 28))
                        .foregroundColor(.white)
                    
                    Text("Stand up and move to continue!")
                        .font(PixelTheme.statsFont(size: 14))
                        .foregroundColor(.white.opacity(0.7))
                    
                    Spacer()
                    
                    // Reset progress
                    VStack(spacing: 16) {
                        HStack(spacing: 30) {
                            ResetStepIndicator(
                                step: 1,
                                title: "STAND",
                                icon: "figure.stand",
                                isComplete: motionManager.resetPhase != .idle
                            )
                            
                            ResetStepIndicator(
                                step: 2,
                                title: "MOVE",
                                icon: "arrow.triangle.2.circlepath",
                                isComplete: motionManager.resetPhase == .movementStarted ||
                                           motionManager.resetPhase == .patternRecognized
                            )
                        }
                        
                        // Progress bar
                        if motionManager.resetPhase != .idle {
                            PixelHealthBar(
                                value: motionManager.resetProgress,
                                maxSegments: 8,
                                segmentColor: PixelTheme.neonGreen,
                                label: "RECOVERY"
                            )
                            .padding(.horizontal, 40)
                        }
                        
                        Text(motionManager.resetPhase.instruction.uppercased())
                            .font(PixelTheme.statsFont(size: 12))
                            .foregroundColor(PixelTheme.electricBlue)
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.7))
                    )
                    .pixelBorder(color: PixelTheme.dangerRed)
                    .padding(.horizontal)
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: feedbackController.isActive)
        .allowsHitTesting(feedbackController.isActive)
    }
}

struct ResetStepIndicator: View {
    let step: Int
    let title: String
    let icon: String
    let isComplete: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isComplete ? PixelTheme.neonGreen : PixelTheme.backgroundCard)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle()
                            .stroke(isComplete ? PixelTheme.neonGreen : PixelTheme.electricBlue.opacity(0.5), lineWidth: 2)
                    )
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.black)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundColor(PixelTheme.electricBlue)
                }
            }
            
            Text(title)
                .font(PixelTheme.statsFont(size: 10))
                .foregroundColor(isComplete ? PixelTheme.neonGreen : .white.opacity(0.7))
        }
    }
}

#Preview {
    ContentView()
}
