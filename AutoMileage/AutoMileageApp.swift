import SwiftUI

@main
struct AutoMileageApp: App {
    @StateObject private var tripVM = TripViewModel()
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(tripVM)
        }
    }
}
