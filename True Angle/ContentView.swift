import SwiftUI
import CoreMotion

class MotionManager: ObservableObject {
    private var motion = CMMotionManager()
    private var referenceRoll: Double = 0.0
    @Published var roll: Double = 0.0
    private var timer: Timer?

    init() {
        startDeviceMotionUpdates()
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
                Text("\(formattedRoll(motionManager.roll))°")
                    .font(.system(size: 180, weight: .semibold, design: .monospaced))
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
            } else if abs(roll - 45) < 0.1 || abs(roll - 90) < 0.1 {
                backgroundColor = Color.blue
            } else if abs(roll + 45) < 0.1 || abs(roll + 90) < 0.1 {
                backgroundColor = Color.blue
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
