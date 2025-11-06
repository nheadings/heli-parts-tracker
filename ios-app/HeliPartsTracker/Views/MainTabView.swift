import SwiftUI

struct MainTabView: View {
    @StateObject private var partsViewModel = PartsViewModel()

    var body: some View {
        TabView {
            PartsListView()
                .environmentObject(partsViewModel)
                .tabItem {
                    Label("Parts", systemImage: "wrench.and.screwdriver")
                }

            HelicoptersListView()
                .environmentObject(partsViewModel)
                .tabItem {
                    Label("Helicopters", systemImage: "helicopter")
                }

            AlertsView()
                .environmentObject(partsViewModel)
                .tabItem {
                    Label("Alerts", systemImage: "exclamationmark.triangle")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
