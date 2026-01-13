import Foundation

/// Represents the user's current focus level based on eye tracking metrics
enum FocusLevel: String, CaseIterable {
    case focused     // Normal usage, healthy blink rate
    case warning     // Reduced blinking, starting to zone out
    case zombie      // Full zombie mode - screen should dim
    case recovering  // Physical reset in progress
    
    var displayName: String {
        switch self {
        case .focused: return "Focused"
        case .warning: return "Attention Needed"
        case .zombie: return "Zombie Mode"
        case .recovering: return "Recovering..."
        }
    }
    
    var emoji: String {
        switch self {
        case .focused: return "🟢"
        case .warning: return "🟡"
        case .zombie: return "🔴"
        case .recovering: return "🔄"
        }
    }
    
    var color: String {
        switch self {
        case .focused: return "green"
        case .warning: return "yellow"
        case .zombie: return "red"
        case .recovering: return "blue"
        }
    }
}

/// Metrics captured from eye tracking
struct EyeMetrics: Equatable {
    let blinkRate: Double           // Blinks per minute (normal: 15-20)
    let eyeOpenness: Double         // 0.0 (closed) to 1.0 (fully open)
    let lastBlinkTime: Date
    let continuousStareTime: TimeInterval  // Seconds since last blink/break
    let estimatedDistance: Double?  // Distance from screen in cm (estimated)
    
    static let zero = EyeMetrics(
        blinkRate: 0,
        eyeOpenness: 1.0,
        lastBlinkTime: Date(),
        continuousStareTime: 0,
        estimatedDistance: nil
    )
    
    /// Normal blink rate is 15-20 per minute
    /// Below 10 indicates "zombie scrolling"
    var isLowBlinkRate: Bool {
        blinkRate < 10
    }
    
    /// Staring for more than 30 seconds without proper blinking
    var isExtendedStare: Bool {
        continuousStareTime > 30
    }
}

/// Phase of the physical reset gesture
enum ResetPhase: String {
    case idle               // Not attempting reset
    case standingDetected   // Device orientation changed (user stood up)
    case movementStarted    // Gyroscope detected significant rotation
    case patternRecognized  // Full reset gesture completed
    
    var instruction: String {
        switch self {
        case .idle: return "Stand up and move to reset"
        case .standingDetected: return "Great! Now wave your phone in a circle"
        case .movementStarted: return "Keep moving..."
        case .patternRecognized: return "Reset complete! 🎉"
        }
    }
}

/// Session statistics for the current day
struct SessionStats {
    var totalFocusTime: TimeInterval = 0
    var totalZombieTime: TimeInterval = 0
    var resetCount: Int = 0
    var sessionStart: Date = Date()
    
    var focusPercentage: Double {
        let total = totalFocusTime + totalZombieTime
        guard total > 0 else { return 100 }
        return (totalFocusTime / total) * 100
    }
    
    var formattedFocusTime: String {
        let minutes = Int(totalFocusTime) / 60
        let seconds = Int(totalFocusTime) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
