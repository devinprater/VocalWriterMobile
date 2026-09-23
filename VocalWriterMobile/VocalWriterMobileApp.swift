import SwiftUI

@main
struct VocalWriterMobileApp: App {
    @StateObject private var studio = StudioModel()

    var body: some Scene {
        WindowGroup {
            StudioTabView()
                .environmentObject(studio)
        }
    }
}

