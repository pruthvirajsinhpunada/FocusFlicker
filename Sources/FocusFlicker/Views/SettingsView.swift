import SwiftUI

/// Settings view for customizing Focus Flicker behavior
struct SettingsView: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var zombieThreshold: Double
    @State private var blinkRateThreshold: Double
    @State private var overlayIntensity: Double
    
    init(appState: AppState) {
        self.appState = appState
        _zombieThreshold = State(initialValue: appState.zombieThreshold)
        _blinkRateThreshold = State(initialValue: appState.blinkRateThreshold)
        _overlayIntensity = State(initialValue: appState.maxOverlayIntensity * 100)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(red: 0.08, green: 0.08, blue: 0.12)
                    .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Detection Settings
                        SettingsSection(title: "Detection") {
                            VStack(spacing: 20) {
                                // Zombie threshold
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Zombie Threshold")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int(zombieThreshold))s")
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Slider(value: $zombieThreshold, in: 10...60, step: 5)
                                        .tint(.blue)
                                    
                                    Text("Time staring before triggering feedback")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                // Blink rate threshold
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Blink Rate Threshold")
                                            .foregroundColor(.white)
                                        Spacer()
                                        Text("\(Int(blinkRateThreshold))/min")
                                            .foregroundColor(.gray)
                                    }
                                    
                                    Slider(value: $blinkRateThreshold, in: 5...15, step: 1)
                                        .tint(.purple)
                                    
                                    Text("Low blink rate indicates distraction")
                                        .font(.caption)
                                        .foregroundColor(.gray)
                                }
                            }
                        }
                        
                        // Feedback Settings
                        SettingsSection(title: "Feedback") {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Overlay Intensity")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("\(Int(overlayIntensity))%")
                                        .foregroundColor(.gray)
                                }
                                
                                Slider(value: $overlayIntensity, in: 30...100, step: 5)
                                    .tint(.orange)
                                
                                Text("Maximum dimming when in zombie mode")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        }
                        
                        // Stats
                        SettingsSection(title: "Today's Stats") {
                            VStack(spacing: 16) {
                                StatRow(
                                    label: "Focus Time",
                                    value: appState.sessionStats.formattedFocusTime,
                                    icon: "brain.head.profile",
                                    color: .green
                                )
                                
                                StatRow(
                                    label: "Focus Score",
                                    value: "\(Int(appState.sessionStats.focusPercentage))%",
                                    icon: "chart.bar.fill",
                                    color: .blue
                                )
                                
                                StatRow(
                                    label: "Resets Today",
                                    value: "\(appState.sessionStats.resetCount)",
                                    icon: "arrow.counterclockwise",
                                    color: .purple
                                )
                            }
                        }
                        
                        // About
                        SettingsSection(title: "About") {
                            VStack(spacing: 12) {
                                HStack {
                                    Text("Version")
                                        .foregroundColor(.white)
                                    Spacer()
                                    Text("1.0.0")
                                        .foregroundColor(.gray)
                                }
                                
                                Divider()
                                    .background(Color.white.opacity(0.1))
                                
                                Text("Focus Flicker uses biological signals to help you build a healthier relationship with your screen.")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        
                        // Reset Onboarding
                        Button(action: resetOnboarding) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Show Onboarding Again")
                            }
                            .foregroundColor(.blue)
                            .padding(.vertical, 12)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        saveSettings()
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            #if os(iOS)
            .toolbarBackground(Color(red: 0.08, green: 0.08, blue: 0.12), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
        }
    }
    
    private func saveSettings() {
        appState.zombieThreshold = zombieThreshold
        appState.blinkRateThreshold = blinkRateThreshold
        appState.maxOverlayIntensity = overlayIntensity / 100
        appState.saveSettings()
    }
    
    private func resetOnboarding() {
        appState.hasCompletedOnboarding = false
        UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
        dismiss()
    }
}

// MARK: - Supporting Views

struct SettingsSection<Content: View>: View {
    let title: String
    let content: Content
    
    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title.uppercased())
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.gray)
            
            content
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.white.opacity(0.05))
                )
        }
    }
}

struct StatRow: View {
    let label: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 24)
            
            Text(label)
                .foregroundColor(.white)
            
            Spacer()
            
            Text(value)
                .fontWeight(.semibold)
                .foregroundColor(color)
        }
    }
}

#Preview {
    SettingsView(appState: AppState())
}
