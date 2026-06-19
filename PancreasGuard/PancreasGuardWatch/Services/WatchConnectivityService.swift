import Foundation
import WatchConnectivity

@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
    var isReachable = false

    override init() {
        super.init()
        if WCSession.isSupported() {
            let session = WCSession.default
            session.delegate = self
            session.activate()
        }
    }

    func sendSymptomEntry(painLevel: Int, hasNausea: Bool, hasVomiting: Bool) {
        guard WCSession.default.isReachable else { return }

        let message: [String: Any] = [
            "type": "symptom",
            "painLevel": painLevel,
            "hasNausea": hasNausea,
            "hasVomiting": hasVomiting,
            "timestamp": Date().timeIntervalSince1970
        ]

        WCSession.default.sendMessage(message, replyHandler: nil)
    }

    // MARK: - WCSessionDelegate

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        Task { @MainActor in
            isReachable = session.isReachable
        }
    }

    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
    #endif

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        // Handle messages from the counterpart app
    }
}
