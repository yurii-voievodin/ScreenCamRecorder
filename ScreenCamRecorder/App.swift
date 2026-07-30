import SwiftUI

@main
struct ScreenCamRecorderApp: App {
    init() {
        setvbuf(stdout, nil, _IONBF, 0)
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowResizability(.contentSize)
    }
}
