import SwiftUI

struct AlertsView: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "airplane.departure")
                    .font(.system(size: 80))
                    .foregroundColor(.blue)

                Text("Flights")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Coming Soon")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
            .navigationTitle("Flights")
        }
    }
}
