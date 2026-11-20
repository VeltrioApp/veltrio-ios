import SwiftUI

@main
struct VeltrioApp: App {
    @State private var store = AppStore()
    @State private var watch = WatchStore()

    init() {
        initLogging()
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(store)
                .environment(watch)
        }
    }
}
