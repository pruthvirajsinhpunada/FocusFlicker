import CoreMotion
import SwiftUI
import Combine
#if os(iOS)
import UIKit
#endif

/// Manages physical reset gesture detection using CoreMotion
@MainActor
class MotionResetManager: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published var resetPhase: ResetPhase = .idle
    @Published var isMonitoring: Bool = false
    @Published var motionPermissionGranted: Bool = false
    @Published var errorMessage: String?
    
    /// Progress through the reset gesture (0.0 to 1.0)
    @Published var resetProgress: Double = 0.0
    
    // MARK: - Private Properties
    
    private let motionManager = CMMotionManager()
    private let operationQueue = OperationQueue()
    
    // Motion detection thresholds
    private let standThreshold: Double = 0.5      // Vertical acceleration change for standing
    private let rotationThreshold: Double = 2.0   // Radians/sec for movement detection
    private let requiredRotations: Double = 2.0   // Number of significant rotations needed
    
    // State tracking
    private var initialAttitude: CMAttitude?
    private var rotationAccumulator: Double = 0.0
    private var standDetectedTime: Date?
    private var lastGyroReading: CMRotationRate?
    
    // Timing
    private let resetTimeout: TimeInterval = 15.0  // Max time to complete gesture
    private var resetStartTime: Date?
    
    // Haptic feedback
    #if os(iOS)
    private let hapticFeedback = UIImpactFeedbackGenerator(style: .medium)
    private let successFeedback = UINotificationFeedbackGenerator()
    #endif
    
    // MARK: - Initialization
    
    init() {
        operationQueue.name = "com.focusflicker.motion"
        operationQueue.maxConcurrentOperationCount = 1
    }
    
    // MARK: - Public Methods
    
    /// Check and request motion permission
    func requestMotionPermission() async -> Bool {
        // Motion permission is checked at runtime on iOS
        // We just need to verify the device supports it
        guard motionManager.isDeviceMotionAvailable else {
            errorMessage = "Device motion is not available on this device"
            motionPermissionGranted = false
            return false
        }
        
        motionPermissionGranted = true
        return true
    }
    
    /// Start monitoring for reset gesture
    func startMonitoring() {
        guard motionManager.isDeviceMotionAvailable else {
            errorMessage = "Device motion not available"
            return
        }
        
        // Configure motion manager
        motionManager.deviceMotionUpdateInterval = 0.02  // 50Hz
        
        motionManager.startDeviceMotionUpdates(to: operationQueue) { [weak self] motion, error in
            guard let self = self, let motion = motion else {
                if let error = error {
                    DispatchQueue.main.async {
                        self?.errorMessage = "Motion error: \(error.localizedDescription)"
                    }
                }
                return
            }
            
            self.processMotionUpdate(motion)
        }
        
        isMonitoring = true
    }
    
    /// Stop monitoring
    func stopMonitoring() {
        motionManager.stopDeviceMotionUpdates()
        isMonitoring = false
        resetState()
    }
    
    /// Manually trigger reset detection (for testing)
    func beginResetAttempt() {
        resetStartTime = Date()
        rotationAccumulator = 0.0
        
        DispatchQueue.main.async {
            self.resetPhase = .standingDetected
            self.resetProgress = 0.25
            #if os(iOS)
            self.hapticFeedback.impactOccurred()
            #endif
        }
    }
    
    // MARK: - Private Methods
    
    private func processMotionUpdate(_ motion: CMDeviceMotion) {
        let now = Date()
        
        // Check for timeout
        if let startTime = resetStartTime,
           now.timeIntervalSince(startTime) > resetTimeout {
            DispatchQueue.main.async {
                self.resetState()
            }
            return
        }
        
        // Get current state on main thread
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            switch self.resetPhase {
            case .idle:
                self.detectStanding(motion: motion)
                
            case .standingDetected, .movementStarted:
                self.detectMovementPattern(motion: motion)
                
            case .patternRecognized:
                // Already completed, wait for reset
                break
            }
        }
    }
    
    /// Detect if user has stood up (significant change in device orientation)
    private func detectStanding(motion: CMDeviceMotion) {
        let gravity = motion.gravity
        let userAccel = motion.userAcceleration
        
        // Check for significant vertical movement (standing up)
        let verticalAcceleration = abs(userAccel.z)
        
        // Also check if device orientation changed significantly
        if initialAttitude == nil {
            initialAttitude = motion.attitude.copy() as? CMAttitude
            return
        }
        
        guard let initial = initialAttitude else { return }
        
        // Calculate attitude change
        let currentAttitude = motion.attitude
        currentAttitude.multiply(byInverseOf: initial)
        
        let pitchChange = abs(currentAttitude.pitch)
        let rollChange = abs(currentAttitude.roll)
        
        // Detect standing: either vertical acceleration or significant orientation change
        let hasStood = verticalAcceleration > standThreshold ||
                       pitchChange > 0.5 ||
                       rollChange > 0.5
        
        if hasStood {
            resetPhase = .standingDetected
            resetStartTime = Date()
            resetProgress = 0.25
            rotationAccumulator = 0.0
            
            #if os(iOS)
            hapticFeedback.impactOccurred()
            #endif
        }
    }
    
    /// Detect circular/wave movement pattern
    private func detectMovementPattern(motion: CMDeviceMotion) {
        let rotationRate = motion.rotationRate
        
        // Calculate total rotation magnitude
        let rotationMagnitude = sqrt(
            rotationRate.x * rotationRate.x +
            rotationRate.y * rotationRate.y +
            rotationRate.z * rotationRate.z
        )
        
        // Accumulate significant rotations
        if rotationMagnitude > rotationThreshold {
            if resetPhase == .standingDetected {
                resetPhase = .movementStarted
                resetProgress = 0.5
                #if os(iOS)
                hapticFeedback.impactOccurred()
                #endif
            }
            
            // Add to accumulator (normalized by update rate)
            rotationAccumulator += rotationMagnitude * 0.02  // dt = 0.02s
        }
        
        // Update progress
        let requiredAccumulation = requiredRotations * 2 * .pi  // Full rotations in radians
        resetProgress = min(0.25 + (rotationAccumulator / requiredAccumulation) * 0.75, 1.0)
        
        // Check if gesture is complete
        if rotationAccumulator >= requiredAccumulation {
            completeReset()
        }
        
        lastGyroReading = rotationRate
    }
    
    /// Complete the reset gesture
    private func completeReset() {
        resetPhase = .patternRecognized
        resetProgress = 1.0
        
        // Strong success feedback
        #if os(iOS)
        successFeedback.notificationOccurred(.success)
        #endif
        
        // Reset after delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { [weak self] in
            self?.resetState()
        }
    }
    
    /// Reset all tracking state
    private func resetState() {
        resetPhase = .idle
        resetProgress = 0.0
        rotationAccumulator = 0.0
        resetStartTime = nil
        initialAttitude = nil
        lastGyroReading = nil
    }
}
