import SwiftUI

struct MainTabView: View {
    @StateObject private var partsViewModel = PartsViewModel()
    @StateObject private var helicoptersViewModel = HelicoptersViewModel()

    var body: some View {
        TabView {
            PartsListView()
                .environmentObject(partsViewModel)
                .tabItem {
                    Label("Parts", systemImage: "wrench.and.screwdriver")
                }

            HelicoptersListView()
                .environmentObject(partsViewModel)
                .environmentObject(helicoptersViewModel)
                .tabItem {
                    Label("Helicopters", image: "HelicopterIcon")
                }

            LogbookView()
                .environmentObject(helicoptersViewModel)
                .tabItem {
                    Label("Logbook", systemImage: "book.closed")
                }

            AlertsView()
                .tabItem {
                    Label("Flights", systemImage: "airplane.departure")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
