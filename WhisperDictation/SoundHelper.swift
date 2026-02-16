import AppKit
import Foundation

enum SoundHelper {
    static func playPing() {
        NSSound(named: "Ping")?.play()
    }

    static func playFrog() {
        NSSound(named: "Frog")?.play()
    }

    static func playError() {
        NSSound(named: "Basso")?.play()
    }
}
