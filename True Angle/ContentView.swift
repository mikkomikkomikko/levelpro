import SwiftUI
import CoreMotion

struct ContentView: View {
    @StateObject private var motionManager = MotionManager() // Referencing the MotionManager class
    @State private var backgroundColor: Color = .black // Initial background color
    private let tolerance: Double = 0.1 // Tolerance for angle comparison

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut, value: backgroundColor) // Animate background color changes

            VStack {
                Text("\(motionManager.pitch, specifier: "%.1f")°")
                    .font(.system(size: 100, weight: .semibold, design: .monospaced)) // Use monospaced font
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
            }
            
            // Invisible button for tap gestures
            Button(action: {
                motionManager.resetReferenceFrame() // Reset on single tap
            }) {
                Color.clear // Make the button invisible
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity) // Ensure it covers the whole screen
            .contentShape(Rectangle()) // Make sure the entire area is tappable
            .onTapGesture {
                motionManager.resetReferenceFrame() // Reset on single tap
            }
            .onTapGesture(count: 2) {
                motionManager.resetToDefault() // Reset coordinates on double tap
            }
        }
        .onReceive(motionManager.$pitch) { newValue in
            updateBackgroundColor(for: newValue) // Update the background color based on the angle
        }
    }
    
    // Function to update the background color based on the angle
    private func updateBackgroundColor(for angle: Double) {
        withAnimation {
            if abs(angle) < tolerance {
                backgroundColor = Color(hex: "#16D743") // Green for angle within tolerance of 0.0°
            } else if abs(angle).closeTo(value: 45.0) || abs(angle).closeTo(value: 90.0) {
                backgroundColor = Color(hex: "#16AAD7") // Blue for ±45° or ±90°
            } else {
                backgroundColor = .black // Default to black for other angles
            }
        }
    }
}

// Extension for Double to compare with a tolerance
extension Double {
    func closeTo(value: Double, tolerance: Double = 0.1) -> Bool {
        return abs(self - value) < tolerance
    }
}

// Extension to initialize Color with hex code
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}

// Update MotionManager to include resetToDefault
class MotionManager: ObservableObject {
    private var motionManager = CMMotionManager()
    @Published var pitch: Double = 0.0 // Angle in degrees
    private var referenceFrame: CMAttitude?
    
    init() {
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let data = data else { return }
            let attitude = data.attitude
            // Calculate pitch as angle in degrees
            self?.pitch = attitude.pitch * 180.0 / .pi - (self?.referenceFrame?.pitch ?? 0.0) * 180.0 / .pi
        }
    }
    
    func resetReferenceFrame() {
        // Set the current attitude as the new reference frame
        if let attitude = motionManager.deviceMotion?.attitude {
            referenceFrame = attitude
        }
    }
    
    func resetToDefault() {
        // Reset pitch to zero
        pitch = 0.0
        referenceFrame = nil // Clear the reference frame
    }
}
