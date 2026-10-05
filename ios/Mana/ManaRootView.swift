import SwiftUI
import ManaCore

struct ManaRootView: View {
    @ObservedObject var model: MobileAppModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var tab = 0
    @State private var route: ProviderRoute?

    var body: some View {
        TabView(selection: $tab) {
            NavigationStack {
                ManaDashboard(model: model, showDetails: { route = .details($0) }, connect: { route = .connect($0) })
            }
            .tabItem { Label("Usage", systemImage: "chart.bar.fill") }
            .tag(0)

            NavigationStack {
                ManaSettingsView(model: model, connect: { route = .connect($0) })
            }
            .tabItem { Label("Settings", systemImage: "gearshape.fill") }
            .tag(1)
        }
        .tint(.manaAccent)
        .sheet(item: $route) { destination in
            switch destination {
            case .details(let provider): ProviderDetailView(model: model, provider: provider)
            case .connect(let provider): ProviderConnectionView(model: model, provider: provider)
            }
        }
        .task { model.setActive(scenePhase == .active) }
        .onChange(of: scenePhase) { _, phase in
            model.setActive(phase == .active)
            if phase == .background {
                ManaBackgroundRefresh.schedule(enabled: !model.isDemo && model.hasConnections)
            }
        }
        .onChange(of: model.isDemo) { _, demo in
            route = nil
            ManaBackgroundRefresh.schedule(enabled: !demo && model.hasConnections)
        }
        .onOpenURL { url in
            guard url.scheme?.lowercased() == "mana", url.host == "provider",
                  let provider = ProviderID(rawValue: url.lastPathComponent),
                  MobileStore.providers.contains(provider) else { return }
            tab = 0
            route = .details(provider)
        }
    }
}

private enum ProviderRoute: Identifiable {
    case details(ProviderID)
    case connect(ProviderID)
    var id: String {
        switch self {
        case .details(let provider): "details-\(provider.rawValue)"
        case .connect(let provider): "connect-\(provider.rawValue)"
        }
    }
}

extension Color {
    static let manaAccent = Color(red: 0.16, green: 0.52, blue: 0.35)
}

struct DemoBanner: View {
    var body: some View {
        Label("Demo • Sample data", systemImage: "sparkles")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.manaAccent.opacity(0.12), in: RoundedRectangle(cornerRadius: 14))
            .accessibilityIdentifier("demo-banner")
    }
}

private struct ManaDashboard: View {
    @ObservedObject var model: MobileAppModel
    let showDetails: (ProviderID) -> Void
    let connect: (ProviderID) -> Void

    var body: some View {
        VStack(spacing: 0) {
            Image("ManaBrandIcon")
                .resizable().scaledToFit()
                .frame(width: 32, height: 32)
                .frame(maxWidth: .infinity)
                .padding(.top, 2)
                .padding(.bottom, 12)
                .accessibilityHidden(true)

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if model.isDemo { DemoBanner() }
                    if !model.hasConnections && !model.isDemo { welcome }
                    if let error = model.serviceError {
                        Label(error, systemImage: "exclamationmark.triangle")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    ForEach(MobileStore.providers) { provider in
                        ProviderQuotaCard(provider: provider, record: model.records[provider] ?? .init(),
                                          isLoading: model.loading.contains(provider), isDemo: model.isDemo,
                                          details: { showDetails(provider) }, connect: { connect(provider) })
                    }
                    Label(model.isDemo ? String(localized: "Try Mana with sample data. Your accounts stay untouched.")
                          : String(localized: "Pull down to refresh."), systemImage: "arrow.clockwise")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
                .frame(maxWidth: 640)
                .frame(maxWidth: .infinity)
            }
            // Reset the provider-card scroll offset when returning to the welcome screen.
            .id(model.isDemo)
            .refreshable { await model.refresh(force: true) }
        }
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Save your mana.")
                .font(.largeTitle.bold())
                .accessibilityIdentifier("welcome-title")
                .accessibilityAddTraits(.isHeader)
            Text("Connect Codex or OpenCode Go and keep an eye on what’s left.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 12)
    }
}
