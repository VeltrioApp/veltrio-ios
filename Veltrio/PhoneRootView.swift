import SwiftUI

/// The app on an iPhone or iPad: the four macOS sections as tabs at the
/// bottom, each with its own navigation stack; search and settings in the
/// top bar. The pages are the shared views (macos/Veltrio/Views); the player
/// goes full screen, bars hidden.
struct PhoneRootView: View {
    @State private var selection: NavItem = .home
    @State private var paths: [NavItem: NavigationPath] = [:]
    @State private var showSettings = false
    @State private var showOnboarding = false
    private let prefs = UserPrefs.shared

    private var preferredScheme: ColorScheme? {
        switch prefs.colorScheme {
        case .system: return nil
        case .dark:   return .dark
        case .light:  return .light
        }
    }

    private func path(_ item: NavItem) -> Binding<NavigationPath> {
        Binding(get: { paths[item] ?? NavigationPath() }, set: { paths[item] = $0 })
    }

    var body: some View {
        TabView(selection: $selection) {
            ForEach(NavItem.allCases) { item in
                NavigationStack(path: path(item)) {
                    VStack(spacing: 0) {
                        topBar
                        section(item).frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .background(Theme.Palette.background.ignoresSafeArea())
                    // The shared pages draw their own back buttons, as on macOS.
                    .toolbar(.hidden, for: .navigationBar)
                    .destinations()
                }
                .tabItem { Label(LocalizedStringKey(item.rawValue), systemImage: item.icon) }
                .tag(item)
            }
        }
        .tint(Theme.Palette.accent)
        .preferredColorScheme(preferredScheme)
        .sheet(isPresented: $showSettings) {
            SettingsSheet().tint(Theme.Palette.accent).preferredColorScheme(preferredScheme)
        }
        .fullScreenCover(isPresented: $showOnboarding) {
            OnboardingView { goToTab in
                showOnboarding = false
                if let goToTab { selection = goToTab }
            }
            .tint(Theme.Palette.accent)
            .preferredColorScheme(preferredScheme)
        }
        .task { await debugLaunch() }
        .onAppear { checkOnboarding() }
        .onReceive(NotificationCenter.default.publisher(for: .veltrioShowOnboarding)) { _ in
            showSettings = false
            showOnboarding = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .veltrioGoto)) { note in
            if let item = note.object as? NavItem { selection = item }
        }
        .onReceive(NotificationCenter.default.publisher(for: .veltrioPlay)) { note in
            if let destination = note.object as? PlayerDestination { path(selection).wrappedValue.append(destination) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .veltrioZap)) { note in
            guard let destination = note.object as? PlayerDestination else { return }
            var p = path(selection).wrappedValue
            if !p.isEmpty { p.removeLast() }
            p.append(destination)
            path(selection).wrappedValue = p
        }
        .onReceive(NotificationCenter.default.publisher(for: .veltrioOpenSearch)) { _ in
            path(selection).wrappedValue.append(SearchDestination())
        }
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
        if let tab = args.string(forKey: "veltrioTab"), let item = NavItem.allCases.first(where: { "\($0)" == tab }) { selection = item }
        if args.bool(forKey: "veltrioSettings") { showSettings = true }
        if let raw = args.string(forKey: "veltrioPlay"), let url = URL(string: raw) {
            path(selection).wrappedValue.append(PlayerDestination(
                kind: .libraryItem(.init(url: url, serverName: "Test", itemId: "test", poster: nil, itemType: "Movie")),
                title: "Test"))
        }
        // `-veltrioTorrent <info hash>` [`-veltrioFileIdx <n>`] plays a torrent through the core's engine.
        if let hash = args.string(forKey: "veltrioTorrent") {
            let stream = Stream(name: "Test", title: "Torrent", description: nil,
                                source: .torrent(infoHash: hash, fileIdx: args.object(forKey: "veltrioFileIdx") == nil ? nil : Int32(args.integer(forKey: "veltrioFileIdx")), sources: []),
                                subtitleLanguages: [], behaviorHintsJson: nil)
            path(selection).wrappedValue.append(PlayerDestination(
                kind: .stream(.init(stream: stream, addonId: "test", addonName: "Test", contentId: "test",
                                    contentType: "movie", videoId: nil, season: nil, episode: nil,
                                    poster: nil, background: nil)),
                title: "Torrent"))
        }
        if args.bool(forKey: "veltrioSearch") { path(selection).wrappedValue.append(SearchDestination()) }
        if let detail = args.string(forKey: "veltrioDetail"), let addon = store.addons.first {
            let parts = detail.split(separator: ":", maxSplits: 1).map(String.init)
            if parts.count == 2 { path(selection).wrappedValue.append(DetailDestination(addon: addon, type: parts[0], id: parts[1], name: parts[1])) }
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

    /// The macOS top bar on a phone: the serif wordmark, search and settings.
    private var topBar: some View {
        HStack(spacing: 4) {
            Text("Veltrio").font(Theme.Font.displaySerif(26, weight: .bold)).foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            Button { path(selection).wrappedValue.append(SearchDestination()) } label: {
                Image(systemName: "magnifyingglass").frame(width: 44, height: 44)
            }
            Button { showSettings = true } label: {
                Image(systemName: "gearshape").frame(width: 44, height: 44)
            }
        }
        .font(.system(size: 18, weight: .medium))
        .foregroundStyle(Theme.Palette.textPrimary)
        .padding(.leading, Theme.Layout.contentInset)
        .padding(.trailing, 8)
        .padding(.vertical, 2)
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
