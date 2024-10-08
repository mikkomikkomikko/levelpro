import SwiftUI
import CoreMotion
import UIKit

class MotionManager: ObservableObject {
    private var motion = CMMotionManager()
    private var referenceRoll: Double = 0.0
    @Published var roll: Double = 0.0
    private var timer: Timer?
    private var hapticGenerator = UIImpactFeedbackGenerator(style: .medium) // Haptic generator
    
    private var hapticTolerance: Double = 0.1 // 0.1° tolerance
    private var hapticDebounceInterval: TimeInterval = 0.5 // 500ms delay
    private var hapticTimer: Timer? // Timer for haptic feedback
    private var hapticTriggered = false // Flag to check if feedback was already triggered

    init() {
        startDeviceMotionUpdates()
        hapticGenerator.prepare() // Prepares the haptic generator for immediate use
    }

    private func startDeviceMotionUpdates() {
        if motion.isDeviceMotionAvailable {
            motion.deviceMotionUpdateInterval = 1.0 / 50.0
            motion.startDeviceMotionUpdates()

            timer = Timer(fire: Date(), interval: 1.0 / 50.0, repeats: true) { [weak self] _ in
                if let data = self?.motion.deviceMotion {
                    let rollInRadians = data.attitude.roll
                    var rollInDegrees = rollInRadians * 180 / .pi
                    
                    rollInDegrees = rollInDegrees.truncatingRemainder(dividingBy: 360)
                    if rollInDegrees > 180 {
                        rollInDegrees -= 360
                    } else if rollInDegrees < -180 {
                        rollInDegrees += 360
                    }
                    
                    let adjustedRoll = rollInDegrees - (self?.referenceRoll ?? 0.0)
                    self?.roll = adjustedRoll >= -180 ? adjustedRoll : adjustedRoll + 360
                }
            }

            if let timer = timer {
                RunLoop.current.add(timer, forMode: .default)
            }
        }
    }

    func stopDeviceMotionUpdates() {
        timer?.invalidate()
        timer = nil
        motion.stopDeviceMotionUpdates()
    }

    func setReferenceFrame() {
        referenceRoll += roll
    }

    func resetToDefaults() {
        referenceRoll = 0.0
    }

    // Function to trigger haptic feedback once
    private func triggerHapticFeedback() {
        hapticGenerator.impactOccurred()
        hapticGenerator.prepare() // Prepare for the next impact
    }

    // Check if roll is within tolerance range and handle haptic feedback logic
    func checkAndTriggerHaptic(for targetRoll: Double) {
        if abs(roll - targetRoll) < hapticTolerance {
            // If inside tolerance and feedback not yet triggered, start debounce timer
            if !hapticTriggered {
                hapticTriggered = true
                hapticTimer?.invalidate() // Cancel any existing timer
                hapticTimer = Timer.scheduledTimer(withTimeInterval: hapticDebounceInterval, repeats: false) { [weak self] _ in
                    self?.triggerHapticFeedback()
                }
            }
        } else {
            // If outside tolerance, reset the triggered flag and invalidate timer
            hapticTriggered = false
            hapticTimer?.invalidate()
        }
    }
}

struct ContentView: View {
    @StateObject private var motionManager = MotionManager()
    @State private var backgroundColor: Color = .black
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
                .animation(.easeInOut, value: backgroundColor)

            VStack {
                Text("\(formattedRoll(abs(motionManager.roll)))°") // Use abs to remove negative sign
                    .font(.system(size: 180, weight: .semibold, design: .monospaced))
                    .tracking(-5)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.white)
            }

            Color.clear
                .contentShape(Rectangle())
                .onTapGesture(count: 2) {
                    motionManager.resetToDefaults()
                }
                .onTapGesture {
                    motionManager.setReferenceFrame()
                }
        }
        .onAppear {
            UIApplication.shared.isIdleTimerDisabled = true // Disable idle timer when the view appears
        }
        .onDisappear {
            UIApplication.shared.isIdleTimerDisabled = false // Re-enable idle timer when the view disappears
        }
        .onReceive(motionManager.$roll) { newRoll in
            updateBackgroundColor(for: newRoll)
        }
    }
    
    // Function to format the roll value with a dot as the decimal separator
    private func formattedRoll(_ roll: Double) -> String {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 1
        formatter.maximumFractionDigits = 1
        formatter.locale = Locale(identifier: "en_US") // Force dot as decimal separator
        return formatter.string(from: NSNumber(value: roll)) ?? "\(roll)"
    }

    private func updateBackgroundColor(for roll: Double) {
        withAnimation {
            if abs(roll) < 0.1 {
                backgroundColor = Color.green
                motionManager.checkAndTriggerHaptic(for: 0.0) // Haptic at 0°
            } else if abs(roll - 45) < 0.1 || abs(roll - 90) < 0.1 {
                backgroundColor = Color.blue
                motionManager.checkAndTriggerHaptic(for: roll > 45 ? 90.0 : 45.0) // Haptic at 45° or 90°
            } else if abs(roll + 45) < 0.1 || abs(roll + 90) < 0.1 {
                backgroundColor = Color.blue
                motionManager.checkAndTriggerHaptic(for: roll < -45 ? -90.0 : -45.0) // Haptic at -45° or -90°
            } else {
                backgroundColor = .black
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
