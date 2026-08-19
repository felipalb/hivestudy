import SwiftUI
import CoreMotion

/// Manages real-time device motion updates to drive physics and parallax effects.
///
/// Converts accelerometer and gyroscope attitude (pitch and roll) into smoothed,
/// normalized [-1.0, 1.0] coordinates for 3D tilts, dynamic shadow projections,
/// specular reflections, and multi-layer depth shifts.
@MainActor
final class MotionManager: ObservableObject {
    @Published var pitch: Double = 0.0  // Forward / backward tilt (-1.0 to 1.0)
    @Published var roll: Double = 0.0   // Left / right tilt (-1.0 to 1.0)

    private let motion = CMMotionManager()
    private var isRunning = false

    /// Starts streaming 60Hz device attitude if hardware sensors are available.
    func start() {
        guard !isRunning, motion.isDeviceMotionAvailable else { return }
        isRunning = true
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, error in
            guard let self, let data, error == nil else { return }

            // Reference pitch ~ 45° (0.78 rad) for a natural phone holding angle.
            let rawPitch = (data.attitude.pitch - 0.78) * 1.8
            let rawRoll = data.attitude.roll * 1.8

            let targetPitch = max(-1.0, min(1.0, rawPitch))
            let targetRoll = max(-1.0, min(1.0, rawRoll))

            // Smooth with exponential moving average for butter-smooth parallax
            self.pitch = self.pitch * 0.84 + targetPitch * 0.16
            self.roll = self.roll * 0.84 + targetRoll * 0.16
        }
    }

    /// Stops sensor updates to conserve battery when the view leaves the screen.
    func stop() {
        guard isRunning else { return }
        isRunning = false
        motion.stopDeviceMotionUpdates()
    }

    deinit {
        motion.stopDeviceMotionUpdates()
    }
}
