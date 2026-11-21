import SwiftUI

/// The app on an iPhone or iPad: the four macOS sections as tabs at the
/// bottom, each with its own navigation stack; search and settings in the
/// top bar. The pages are the shared views (macos/Veltrio/Views); the player
/// goes full screen, bars hidden.
struct PhoneRootView: View {
    private enum PhoneTab: Hashable {
        case section(NavItem)
        case search
        case settings
    }

    @State private var selection: PhoneTab = .section(.home)
    @State private var paths: [PhoneTab: NavigationPath] = [:]
    @State private var showOnboarding = false
    private let prefs = UserPrefs.shared

    private var preferredScheme: ColorScheme? {
        switch prefs.colorScheme {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }

    private func path(_ tab: PhoneTab) -> Binding<NavigationPath> {
        Binding(get: { paths[tab] ?? NavigationPath() }, set: { paths[tab] = $0 })
    }

    private var activeNavTab: PhoneTab {
        if case .settings = selection { return .section(.home) }
        return selection
    }

    var body: some View {
        tabContent
            .tint(Theme.Palette.accent)
            .preferredColorScheme(preferredScheme)
            .fullScreenCover(isPresented: $showOnboarding) {
                OnboardingView { goToTab in
                    showOnboarding = false
                    if let goToTab { selection = .section(goToTab) }
                }
                .tint(Theme.Palette.accent)
                .preferredColorScheme(preferredScheme)
            }
            .task { await debugLaunch() }
            .onAppear { checkOnboarding() }
            .onReceive(NotificationCenter.default.publisher(for: .veltrioShowOnboarding)) { _ in
                showOnboarding = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .veltrioGoto)) { note in
                if let item = note.object as? NavItem { selection = .section(item) }
            }
            .onReceive(NotificationCenter.default.publisher(for: .veltrioPlay)) { note in
                if let destination = note.object as? PlayerDestination {
                    if case .settings = selection { selection = .section(.home) }
                    path(activeNavTab).wrappedValue.append(destination)
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .veltrioZap)) { note in
                guard let destination = note.object as? PlayerDestination else { return }
                var p = path(activeNavTab).wrappedValue
                if !p.isEmpty { p.removeLast() }
                p.append(destination)
                path(activeNavTab).wrappedValue = p
            }
            .onReceive(NotificationCenter.default.publisher(for: .veltrioOpenSearch)) { _ in
                selection = .search
            }
    }

    @ViewBuilder
    private var tabContent: some View {
        if #available(iOS 18.0, *) {
            TabView(selection: $selection) {
                ForEach(NavItem.allCases) { item in
                    Tab(LocalizedStringKey(item.rawValue), systemImage: item.icon, value: PhoneTab.section(item)) {
                        sectionStack(item)
                    }
                }
                Tab(LocalizedStringKey("Settings"), systemImage: "gearshape.fill", value: PhoneTab.settings) {
                    settingsTab
                }
                Tab(LocalizedStringKey("Search"), systemImage: "magnifyingglass", value: PhoneTab.search, role: .search) {
                    searchTab
                }
            }
        } else {
            TabView(selection: $selection) {
                ForEach(NavItem.allCases) { item in
                    sectionStack(item)
                        .tabItem { Label(LocalizedStringKey(item.rawValue), systemImage: item.icon) }
                        .tag(PhoneTab.section(item))
                }
                searchTab
                    .tabItem { Label(LocalizedStringKey("Search"), systemImage: "magnifyingglass") }
                    .tag(PhoneTab.search)
                settingsTab
                    .tabItem { Label(LocalizedStringKey("Settings"), systemImage: "gearshape.fill") }
                    .tag(PhoneTab.settings)
            }
        }
    }

    private func sectionStack(_ item: NavItem) -> some View {
        NavigationStack(path: path(.section(item))) {
            VStack(spacing: 0) {
                topBar
                section(item).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            // The shared pages draw their own back buttons, as on macOS.
            .toolbar(.hidden, for: .navigationBar)
            .destinations()
        }
    }

    private var searchTab: some View {
        NavigationStack(path: path(.search)) {
            VStack(spacing: 0) {
                topBar
                SearchView().frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .background(Theme.Palette.background.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .destinations()
        }
    }

    private var settingsTab: some View {
        VStack(spacing: 0) {
            topBar
            SettingsView()
        }
        .background(Theme.Palette.background.ignoresSafeArea())
    }

    @Environment(AppStore.self) private var store

    private func checkOnboarding() {
        #if DEBUG
        let args = UserDefaults.standard
        if args.bool(forKey: "veltrioOnboarding") {
            showOnboarding = true
            return
        }
        if args.string(forKey: "veltrioInstall") != nil
            || args.string(forKey: "veltrioPlay") != nil
            || args.string(forKey: "veltrioDetail") != nil
            || args.bool(forKey: "veltrioSettings")
            || args.bool(forKey: "veltrioSearch") {
            return
        }
        #endif
        if !prefs.hasCompletedOnboarding {
            let alreadyConfigured = !store.addons.isEmpty || !store.iptvPlaylists.isEmpty
                || store.jellyfin.isConnected || store.emby.isConnected || store.plex.isConnected
            if alreadyConfigured {
                prefs.hasCompletedOnboarding = true
            } else {
                showOnboarding = true
            }
        }
    }

    /// Debug builds: `-veltrioInstall <manifest url>`, `-veltrioTab home|library|iptv|addons`,
    /// `-veltrioDetail <type>:<id>` set the app up for screenshots in the
    /// simulator, where nothing can be tapped from a script.
    private func debugLaunch() async {
        #if DEBUG
        let args = UserDefaults.standard
        if let url = args.string(forKey: "veltrioInstall"), !store.addons.contains(where: { $0.manifest.transportUrl == url }) {
            await store.installAddon(url: url)
        }
        if let tab = args.string(forKey: "veltrioTab"), let item = NavItem.allCases.first(where: { "\($0)" == tab }) { selection = .section(item) }
        if args.bool(forKey: "veltrioSettings") { selection = .settings }
        if let raw = args.string(forKey: "veltrioPlay"), let url = URL(string: raw) {
            path(activeNavTab).wrappedValue.append(PlayerDestination(
                kind: .libraryItem(.init(url: url, serverName: "Test", itemId: "test", poster: nil, itemType: "Movie")),
                title: "Test"))
        }
        // `-veltrioTorrent <info hash>` [`-veltrioFileIdx <n>`] plays a torrent through the core's engine.
        if let hash = args.string(forKey: "veltrioTorrent") {
            let stream = Stream(name: "Test", title: "Torrent", description: nil,
                                source: .torrent(infoHash: hash, fileIdx: args.object(forKey: "veltrioFileIdx") == nil ? nil : Int32(args.integer(forKey: "veltrioFileIdx")), sources: []),
                                subtitleLanguages: [], behaviorHintsJson: nil)
            path(activeNavTab).wrappedValue.append(PlayerDestination(
                kind: .stream(.init(stream: stream, addonId: "test", addonName: "Test", contentId: "test",
                                    contentType: "movie", videoId: nil, season: nil, episode: nil,
                                    poster: nil, background: nil)),
                title: "Torrent"))
        }
        if args.bool(forKey: "veltrioSearch") { selection = .search }
        if let detail = args.string(forKey: "veltrioDetail"), let addon = store.addons.first {
            let parts = detail.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 { path(activeNavTab).wrappedValue.append(DetailDestination(addon: addon, type: parts[0], id: parts[1], name: parts[1])) }
        }
        #endif
    }

    @ViewBuilder
    private func section(_ item: NavItem) -> some View {
        switch item {
        case .home:    HomeView()
        case .library: LibraryView()
        case .iptv:    IPTVView()
        case .addons:  SourcesView()
        }
    }

    /// Minimal editorial header with the Veltrio wordmark.
    private var topBar: some View {
        HStack {
            Text("Veltrio").font(Theme.Font.displaySerif(26, weight: .bold)).foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
        }
        .padding(.horizontal, Theme.Layout.contentInset)
        .padding(.vertical, 8)
    }

}

private extension View {
    /// The pages any tab can open, as on macOS.
    func destinations() -> some View {
        self
            .navigationDestination(for: DetailDestination.self) { DetailView(destination: $0).toolbar(.hidden, for: .tabBar) }
            .navigationDestination(for: PlayerDestination.self) { dest in
                // One player per destination: zapping replaces the top of
                // the stack, and a reused view would keep the old stream.
                PlayerView(destination: dest)
                    .id(dest)
                    .toolbar(.hidden, for: .tabBar, .navigationBar)
                    .ignoresSafeArea()
            }
            .navigationDestination(for: MediaServerSeriesDestination.self) { MediaServerSeriesView(destination: $0) }
            .navigationDestination(for: IptvSeriesDestination.self) { IptvSeriesView(destination: $0) }
            .navigationDestination(for: SearchDestination.self) { _ in SearchView() }
            .navigationDestination(for: CatalogDestination.self) { CatalogGridView(destination: $0) }
    }
}
