import SwiftUI

@main
struct VeltrioApp: App {
    @State private var store = AppStore()
    @State private var watch = WatchStore()
    @State private var prefs = UserPrefs.shared

    init() {
        // The core's torrent engine writes under $HOME/.cache: in an iOS
        // container that's the Caches folder (purgeable, not backed up).
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        setenv("HOME", caches.path, 1)
        initLogging()
    }

    var body: some Scene {
        WindowGroup {
            PhoneRootView()
                .environment(store)
                .environment(watch)
                .environment(\.locale, prefs.resolvedLocale)
        }
    }
}
