import MediaPlayer

/// Routes the headphone / lock-screen play-pause button to a callback.
/// iOS only delivers these to the current "Now Playing" app, so we claim
/// Now-Playing (without pausing other audio) while enabled.
final class RemoteControl {
    private let center = MPRemoteCommandCenter.shared()
    private var wired = false
    var onTrigger: (() -> Void)?

    func enable() {
        guard !wired else { return }
        wired = true

        let handler: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { [weak self] _ in
            DispatchQueue.main.async { self?.onTrigger?() }
            return .success
        }
        center.togglePlayPauseCommand.addTarget(handler: handler)
        center.playCommand.addTarget(handler: handler)
        center.pauseCommand.addTarget(handler: handler)

        // Claim the transport controls so the button is routed to us.
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [
            MPMediaItemPropertyTitle: "Genius",
            MPNowPlayingInfoPropertyPlaybackRate: 1.0
        ]
    }

    func disable() {
        guard wired else { return }
        wired = false
        center.togglePlayPauseCommand.removeTarget(nil)
        center.playCommand.removeTarget(nil)
        center.pauseCommand.removeTarget(nil)
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
    }
}
