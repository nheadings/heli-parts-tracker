import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authViewModel: AuthViewModel
    @StateObject private var partsViewModel = PartsViewModel()
    @StateObject private var helicoptersViewModel = HelicoptersViewModel()

    var body: some View {
        TabView {
            PartsListView()
                .environmentObject(partsViewModel)
                .environmentObject(authViewModel)
                .tabItem {
                    Label("Parts", systemImage: "wrench.and.screwdriver")
                }

            HelicoptersListView()
                .environmentObject(partsViewModel)
                .environmentObject(helicoptersViewModel)
                .environmentObject(authViewModel)
                .tabItem {
                    Label("Helicopters", image: "HelicopterIcon")
                }

            UnifiedLogbookView()
                .environmentObject(helicoptersViewModel)
                .environmentObject(authViewModel)
                .tabItem {
                    Label("Logbook", systemImage: "book.closed")
                }

            FlightView()
                .environmentObject(helicoptersViewModel)
                .environmentObject(authViewModel)
                .tabItem {
                    Label("Flights", systemImage: "airplane.departure")
                }

            SettingsView()
                .environmentObject(authViewModel)
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
        }
    }
}
