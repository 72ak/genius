import AVFoundation

/// Owns the shared audio session. Records continuously while letting other
/// audio (music, podcasts) keep playing, and ducks that audio *only* while the
/// app is speaking a TTS answer — so music is quieted, never paused.
final class AudioSessionManager {
    static let shared = AudioSessionManager()
    private let session = AVAudioSession.sharedInstance()

    private let baseOptions: AVAudioSession.CategoryOptions =
        [.mixWithOthers, .allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]

    func configureForListening() throws {
        try session.setCategory(.playAndRecord, mode: .spokenAudio, options: baseOptions)
        try session.setActive(true)
    }

    /// Toggle ducking of other apps' audio. Called around TTS playback.
    func setDucking(_ ducking: Bool) {
        let options = ducking ? baseOptions.union(.duckOthers) : baseOptions
        try? session.setCategory(.playAndRecord, mode: .spokenAudio, options: options)
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
}
