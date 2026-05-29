import AVFoundation

/// Owns the shared audio session. Records continuously while letting other
/// audio (music, podcasts) keep playing, and ducks that audio *only* while the
/// app is speaking a TTS answer — so music is quieted, never paused.
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    private let session = AVAudioSession.sharedInstance()
    private var isDucking = false

    // No .allowBluetooth (that forces the low-quality headset mic). A2DP keeps
    // high-quality output in AirPods while we record from the phone's own mic.
    private let baseOptions: AVAudioSession.CategoryOptions =
        [.mixWithOthers, .allowBluetoothA2DP, .defaultToSpeaker]

    func configureForListening() throws {
        let options = isDucking ? baseOptions.union(.duckOthers) : baseOptions
        try session.setCategory(.playAndRecord, mode: .measurement, options: options)
        try session.setActive(true)
        preferBuiltInMic()
    }

    /// Capture from the phone's own mic — better at picking up the room and
    /// distant speakers — even when AirPods are used for output.
    func preferBuiltInMic() {
        guard let builtIn = session.availableInputs?.first(where: { $0.portType == .builtInMic }) else { return }
        try? session.setPreferredInput(builtIn)
        preferMostUsefulDataSource(for: builtIn)
    }

    /// Toggle ducking of other apps' audio. Called around TTS playback.
    func setDucking(_ ducking: Bool) {
        isDucking = ducking
        let options = ducking ? baseOptions.union(.duckOthers) : baseOptions
        try? session.setCategory(.playAndRecord, mode: .measurement, options: options)
        preferBuiltInMic()
        NotificationCenter.default.post(name: .audioSessionReconfigured, object: nil)
    }

    /// True if a wired or Bluetooth headset is the current output route.
    var headphonesConnected: Bool {
        session.currentRoute.outputs.contains { output in
            switch output.portType {
            case .headphones, .bluetoothA2DP, .bluetoothHFP, .bluetoothLE, .airPlay, .usbAudio:
                return true
            default:
                return false
            }
        }
    }

    private func preferMostUsefulDataSource(for input: AVAudioSessionPortDescription) {
        guard let sources = input.dataSources, !sources.isEmpty else { return }
        let preferred = sources.first { source in
            let name = source.dataSourceName.lowercased()
            return name.contains("bottom") || name.contains("front") || name.contains("back")
        } ?? sources.first
        if let preferred {
            try? input.setPreferredDataSource(preferred)
        }
    }
}
