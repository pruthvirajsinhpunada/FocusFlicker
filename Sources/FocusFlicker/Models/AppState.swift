import SwiftUI
import Combine

/// Central app state management using ObservableObject pattern
@MainActor
class AppState: ObservableObject {
    // MARK: - Published State
    
    /// Current focus level based on eye tracking
    @Published var focusLevel: FocusLevel = .focused
    
    /// Latest eye tracking metrics
    @Published var eyeMetrics: EyeMetrics = .zero
    
    /// Current phase of reset gesture
    @Published var resetPhase: ResetPhase = .idle
    
    /// Session statistics
    @Published var sessionStats: SessionStats = SessionStats()
    
    /// Whether the feedback overlay should be visible
    @Published var showOverlay: Bool = false
    
    /// Intensity of the overlay (0.0 to 1.0)
    @Published var overlayIntensity: Double = 0.0
    
    /// Whether onboarding has been completed
    @Published var hasCompletedOnboarding: Bool = false
    
    /// Whether eye tracking is active
    @Published var isTrackingActive: Bool = false
    
    /// Error message to display
    @Published var errorMessage: String?
    
    // MARK: - Settings
    
    /// Seconds before zombie mode triggers
    @Published var zombieThreshold: TimeInterval = 30
    
    /// Blink rate threshold (blinks per minute)
    @Published var blinkRateThreshold: Double = 10
    
    /// Maximum overlay intensity (0.0 to 1.0)
    @Published var maxOverlayIntensity: Double = 0.7
    
    /// How quickly the overlay fades in (seconds)
    @Published var overlayFadeInDuration: TimeInterval = 10
    
    // MARK: - Private
    
    private var lastStateChange: Date = Date()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        setupStateTracking()
        loadSettings()
    }
    
    // MARK: - Public Methods
    
    /// Update focus level based on eye metrics
    func updateFocusLevel(from metrics: EyeMetrics) {
        eyeMetrics = metrics
        
        let previousLevel = focusLevel
        
        // Determine new focus level
        if resetPhase != .idle && resetPhase != .patternRecognized {
            focusLevel = .recovering
        } else if metrics.isExtendedStare && metrics.isLowBlinkRate {
            focusLevel = .zombie
            showOverlay = true
            
            // Calculate overlay intensity based on how long in zombie mode
            let zombieDuration = metrics.continuousStareTime - zombieThreshold
            let progress = min(zombieDuration / overlayFadeInDuration, 1.0)
            overlayIntensity = progress * maxOverlayIntensity
            
        } else if metrics.isLowBlinkRate || metrics.continuousStareTime > (zombieThreshold * 0.7) {
            focusLevel = .warning
            showOverlay = false
            overlayIntensity = 0
        } else {
            focusLevel = .focused
            showOverlay = false
            overlayIntensity = 0
        }
        
        // Track state duration for stats
        if previousLevel != focusLevel {
            let duration = Date().timeIntervalSince(lastStateChange)
            
            switch previousLevel {
            case .focused:
                sessionStats.totalFocusTime += duration
            case .zombie:
                sessionStats.totalZombieTime += duration
            default:
                break
            }
            
            lastStateChange = Date()
        }
    }
    
    /// Called when physical reset gesture is completed
    func completeReset() {
        resetPhase = .patternRecognized
        sessionStats.resetCount += 1
        
        // Clear the zombie state
        focusLevel = .focused
        showOverlay = false
        overlayIntensity = 0
        
        // Reset after a delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { [weak self] in
            self?.resetPhase = .idle
        }
    }
    
    /// Update reset phase from motion detection
    func updateResetPhase(_ phase: ResetPhase) {
        resetPhase = phase
        
        if phase == .patternRecognized {
            completeReset()
        }
    }
    
    /// Mark onboarding as complete
    func completeOnboarding() {
        hasCompletedOnboarding = true
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
    }
    
    // MARK: - Private Methods
    
    private func setupStateTracking() {
        // Update stats every second while active
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, self.isTrackingActive else { return }
                
                let duration: TimeInterval = 1.0
                switch self.focusLevel {
                case .focused:
                    self.sessionStats.totalFocusTime += duration
                case .zombie:
                    self.sessionStats.totalZombieTime += duration
                default:
                    break
                }
            }
            .store(in: &cancellables)
    }
    
    private func loadSettings() {
        hasCompletedOnboarding = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        
        if let threshold = UserDefaults.standard.object(forKey: "zombieThreshold") as? TimeInterval {
            zombieThreshold = threshold
        }
        
        if let blinkRate = UserDefaults.standard.object(forKey: "blinkRateThreshold") as? Double {
            blinkRateThreshold = blinkRate
        }
    }
    
    func saveSettings() {
        UserDefaults.standard.set(zombieThreshold, forKey: "zombieThreshold")
        UserDefaults.standard.set(blinkRateThreshold, forKey: "blinkRateThreshold")
    }
}
