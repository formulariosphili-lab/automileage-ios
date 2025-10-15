import SwiftUI
import CoreLocation

struct ContentView: View {
    @EnvironmentObject var vm: TripViewModel

    var body: some View {
        NavigationView {
            VStack(spacing: 16) {
                VStack {
                    Text(vm.statusText)
                        .font(.title2).bold()
                    Text(vm.substatusText)
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                }
                .padding()

                HStack {
                    Label("Trips this session", systemImage: "car.fill")
                    Spacer()
                    Text("\(vm.trips.count)")
                }
                .padding(.horizontal)

                List {
                    ForEach(vm.trips) { trip in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(trip.title)
                                .font(.headline)
                            Text(trip.subtitle)
                                .font(.footnote)
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Button {
                    vm.exportCSV()
                } label: {
                    Text("Export CSV")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .padding(.horizontal)
            }
            .navigationTitle("AutoMileage")
            .onAppear { vm.start() }
        }
    }
}

final class TripViewModel: ObservableObject {
    @Published var statusText: String = "Preparing…"
    @Published var substatusText: String = "Grant Location (Always) and Motion access for auto-detection."
    @Published var trips: [TripSummary] = []

    private let manager = TripManager()

    func start() {
        manager.onStatusChange = { [weak self] status, detail in
            DispatchQueue.main.async {
                self?.statusText = status
                self?.substatusText = detail ?? ""
            }
        }
        manager.onTripClosed = { [weak self] summary in
            DispatchQueue.main.async {
                self?.trips.insert(summary, at: 0)
            }
        }
        manager.start()
    }

    func exportCSV() {
        let csv = CSVExport.makeCSV(trips: trips)
        CSVExport.share(text: csv)
    }
}

struct TripSummary: Identifiable {
    let id = UUID()
    let startTime: Date
    let endTime: Date
    let distanceMeters: Double
    let startAddress: String?
    let endAddress: String?

    var title: String {
        let miles = distanceMeters / 1609.344
        return String(format: "%.1f miles  •  %@", miles, DateFormatter.shortTime.string(from: startTime))
    }

    var subtitle: String {
        let fmt = DateFormatter.shortTime
        let start = startAddress ?? "Start"
        let end = endAddress ?? "End"
        return "\(fmt.string(from: startTime)) → \(fmt.string(from: endTime))  •  \(start) → \(end)"
    }
}

extension DateFormatter {
    static let shortTime: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .short
        return df
    }()
}
