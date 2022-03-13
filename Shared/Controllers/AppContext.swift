import SwiftUI
import LiveKit
import WebRTC
import Combine

extension ObservableObject where Self.ObjectWillChangePublisher == ObservableObjectPublisher {
    func notify() {
        DispatchQueue.main.async { self.objectWillChange.send() }
    }
}

// This class contains the logic to control behavior of the whole app.
final class AppContext: ObservableObject {

    private let store: ValueStore<Preferences>

    @Published var videoViewVisible: Bool = true {
        didSet { store.value.videoViewVisible = videoViewVisible }
    }

    @Published var showInformationOverlay: Bool = false {
        didSet { store.value.showInformationOverlay = showInformationOverlay }
    }

    @Published var preferMetal: Bool = true {
        didSet { store.value.preferMetal = preferMetal }
    }

    @Published var videoViewMode: VideoView.LayoutMode = .fit {
        didSet { store.value.videoViewMode = videoViewMode }
    }

    @Published var videoViewMirrored: Bool = false {
        didSet { store.value.videoViewMirrored = videoViewMirrored }
    }

    @Published var connectionHistory: Set<ConnectionHistory> = [] {
        didSet { store.value.connectionHistory = connectionHistory }
    }

    @Published var playoutDevice: RTCIODevice = RTCAudioDevice.defaultDevice() {
        didSet {
            print("didSet playoutDevice: \(String(describing: playoutDevice))")

            let adm = Room.audioDeviceModule()
            if !adm.switchPlayoutDevice(playoutDevice) {
                print("failed to set value")
            }
        }
    }

    @Published var recordingDevice: RTCIODevice = RTCDevice.defaultDevice(with: .input) {
        didSet {
            print("didSet recordingDevice: \(String(describing: recordingDevice))")

            let adm = Room.audioDeviceModule()
            if !adm.switchRecording(recordingDevice) {
                print("failed to set value")
            }
        }
    }

    public init(store: ValueStore<Preferences>) {
        self.store = store

        store.onLoaded.then { preferences in
            self.videoViewVisible = preferences.videoViewVisible
            self.showInformationOverlay = preferences.showInformationOverlay
            self.preferMetal = preferences.preferMetal
            self.videoViewMode = preferences.videoViewMode
            self.videoViewMirrored = preferences.videoViewMirrored
            self.connectionHistory = preferences.connectionHistory
        }
    }
}
