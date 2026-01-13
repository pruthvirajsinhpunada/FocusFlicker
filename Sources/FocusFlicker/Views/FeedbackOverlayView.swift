import SwiftUI

/// Feedback overlay that dims and desaturates the screen
struct FeedbackOverlayView: View {
    @ObservedObject var feedbackController: ScreenFeedbackController
    @ObservedObject var motionManager: MotionResetManager
    
    var body: some View {
        ZStack {
            // Dimming overlay
            Rectangle()
                .fill(Color.black.opacity(feedbackController.overlayOpacity))
                .ignoresSafeArea()
            
            // Grayscale effect layer
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.gray.opacity(feedbackController.desaturation * 0.3),
                            Color(white: 0.5).opacity(feedbackController.desaturation * 0.2)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .blendMode(.saturation)
                .ignoresSafeArea()
            
            // Recovery instructions
            if feedbackController.isActive {
                VStack(spacing: 24) {
                    Spacer()
                    
                    // Warning icon
                    Image(systemName: "eye.slash.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.9))
                        .shadow(color: .black, radius: 10)
                    
                    Text("Zombie Mode Detected")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .black, radius: 5)
                    
                    Text("You've been staring without blinking")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Spacer()
                    
                    // Reset instructions
                    VStack(spacing: 16) {
                        Text("To unlock:")
                            .font(.headline)
                            .foregroundColor(.white)
                        
                        HStack(spacing: 20) {
                            InstructionStep(
                                number: 1,
                                icon: "figure.stand",
                                text: "Stand up",
                                isComplete: motionManager.resetPhase != .idle
                            )
                            
                            InstructionStep(
                                number: 2,
                                icon: "arrow.triangle.2.circlepath",
                                text: "Wave phone",
                                isComplete: motionManager.resetPhase == .movementStarted ||
                                           motionManager.resetPhase == .patternRecognized
                            )
                        }
                        
                        // Progress indicator
                        if motionManager.resetPhase != .idle {
                            ProgressView(value: motionManager.resetProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .green))
                                .frame(width: 200)
                                .padding(.top, 8)
                            
                            Text(motionManager.resetPhase.instruction)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                    .padding(24)
                    .background(
                        RoundedRectangle(cornerRadius: 20)
                            .fill(Color.black.opacity(0.5))
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20))
                    )
                    
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.5), value: feedbackController.isActive)
        .allowsHitTesting(feedbackController.isActive)
    }
}

/// Individual instruction step for reset gesture
struct InstructionStep: View {
    let number: Int
    let icon: String
    let text: String
    let isComplete: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(isComplete ? Color.green : Color.white.opacity(0.2))
                    .frame(width: 50, height: 50)
                
                if isComplete {
                    Image(systemName: "checkmark")
                        .font(.title2)
                        .foregroundColor(.white)
                } else {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundColor(.white)
                }
            }
            
            Text(text)
                .font(.caption)
                .foregroundColor(.white)
        }
    }
}

#Preview {
    FeedbackOverlayView(
        feedbackController: {
            let controller = ScreenFeedbackController()
            controller.overlayOpacity = 0.5
            controller.desaturation = 0.6
            controller.isActive = true
            return controller
        }(),
        motionManager: {
            let manager = MotionResetManager()
            return manager
        }()
    )
}
