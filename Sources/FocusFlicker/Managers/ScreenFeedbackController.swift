import SwiftUI
import Combine

/// Controls the screen feedback overlay for visual dimming/desaturation
@MainActor
class ScreenFeedbackController: ObservableObject {
    
    // MARK: - Published Properties
    
    /// Current overlay opacity (0.0 to 1.0)
    @Published var overlayOpacity: Double = 0.0
    
    /// Current desaturation level (0.0 = full color, 1.0 = grayscale)
    @Published var desaturation: Double = 0.0
    
    /// Whether feedback is currently active
    @Published var isActive: Bool = false
    
    // MARK: - Private Properties
    
    private var animationTimer: Timer?
    private var targetOpacity: Double = 0.0
    private var targetDesaturation: Double = 0.0
    
    private let animationSpeed: Double = 0.02  // Change per frame
    private let maxOpacity: Double = 0.7
    private let maxDesaturation: Double = 0.8
    private let frameInterval: TimeInterval = 1.0 / 60.0  // 60 FPS
    
    // MARK: - Initialization
    
    init() {}
    
    // MARK: - Public Methods
    
    /// Activate the feedback overlay with specified intensity
    /// - Parameter intensity: 0.0 (none) to 1.0 (maximum)
    func activate(intensity: Double) {
        let clampedIntensity = min(max(intensity, 0.0), 1.0)
        
        targetOpacity = clampedIntensity * maxOpacity
        targetDesaturation = clampedIntensity * maxDesaturation
        
        if !isActive {
            isActive = true
            startAnimation()
        }
    }
    
    /// Immediately deactivate and reset the overlay
    func deactivate() {
        targetOpacity = 0.0
        targetDesaturation = 0.0
        
        // Animate out
        startAnimation()
    }
    
    /// Immediately reset without animation
    func reset() {
        stopAnimation()
        overlayOpacity = 0.0
        desaturation = 0.0
        isActive = false
    }
    
    // MARK: - Private Methods
    
    private func startAnimation() {
        guard animationTimer == nil else { return }
        
        animationTimer = Timer.scheduledTimer(withTimeInterval: frameInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateAnimation()
            }
        }
    }
    
    private func stopAnimation() {
        animationTimer?.invalidate()
        animationTimer = nil
    }
    
    private func updateAnimation() {
        var needsUpdate = false
        
        // Animate opacity
        if abs(overlayOpacity - targetOpacity) > 0.001 {
            if overlayOpacity < targetOpacity {
                overlayOpacity = min(overlayOpacity + animationSpeed, targetOpacity)
            } else {
                overlayOpacity = max(overlayOpacity - animationSpeed * 2, targetOpacity)  // Faster fade out
            }
            needsUpdate = true
        }
        
        // Animate desaturation
        if abs(desaturation - targetDesaturation) > 0.001 {
            if desaturation < targetDesaturation {
                desaturation = min(desaturation + animationSpeed, targetDesaturation)
            } else {
                desaturation = max(desaturation - animationSpeed * 2, targetDesaturation)
            }
            needsUpdate = true
        }
        
        // Check if animation complete
        if !needsUpdate {
            if targetOpacity == 0 && targetDesaturation == 0 {
                isActive = false
            }
            stopAnimation()
        }
    }
}

// MARK: - Grayscale Color Matrix

extension ScreenFeedbackController {
    /// Generate a color matrix for desaturation effect
    /// Used with CIColorMatrix or similar filters
    var colorMatrix: [CGFloat] {
        let s = 1.0 - desaturation
        
        // Luminance-preserving grayscale conversion
        // R' = 0.299R + 0.587G + 0.114B
        // When s = 0, fully grayscale; when s = 1, full color
        
        let r: CGFloat = 0.299
        let g: CGFloat = 0.587
        let b: CGFloat = 0.114
        
        return [
            r + s * (1 - r), g - s * g,     b - s * b,     0,
            r - s * r,       g + s * (1-g), b - s * b,     0,
            r - s * r,       g - s * g,     b + s * (1-b), 0,
            0,               0,             0,             1
        ]
    }
}
