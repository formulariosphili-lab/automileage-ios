import Foundation
import CoreLocation
import CoreMotion

final class TripManager: NSObject, CLLocationManagerDelegate {

    enum State { case idle, drivingCandidate, driving, stoppingCandidate }

    private let location = CLLocationManager()
    private let motion = CMMotionActivityManager()
    private var state: State = .idle

    private var lastPoints: [CLLocation] = []
    private var isInVehicle = false
    private var stopCandidateBegan: Date?
    private var tripStart: CLLocation?
    private var tripPoints: [CLLocation] = []

    // Callbacks for UI
    var onStatusChange: ((String, String?) -> Void)?
    var onTripClosed: ((TripSummary) -> Void)?

    override init() {
        super.init()
        location.delegate = self
        location.allowsBackgroundLocationUpdates = true
        location.pausesLocationUpdatesAutomatically = true
        onStatusChange?("Idle", "Waiting for motion…")
    }

    func start() {
        requestPermissions()
        location.startMonitoringSignificantLocationChanges()
        startMotion()
        notify("Ready", "Waiting to detect driving…")
    }

    private func requestPermissions() {
        switch location.authorizationStatus {
        case .notDetermined:
            location.requestAlwaysAuthorization()
        case .authorizedWhenInUse:
            location.requestAlwaysAuthorization()
        default:
            break
        }
    }

    private func startMotion() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }
        motion.startActivityUpdates(to: .main) { [weak self] activity in
            guard let self, let a = activity else { return }
            self.isInVehicle = a.automotive && !a.stationary
            self.evaluateState()
        }
    }

    private func elevateGPS() {
        location.stopMonitoringSignificantLocationChanges()
        location.desiredAccuracy = kCLLocationAccuracyBest
        location.distanceFilter = 25 // meters
        location.startUpdatingLocation()
    }

    private func lowerGPS() {
        location.stopUpdatingLocation()
        location.startMonitoringSignificantLocationChanges()
    }

    private func evaluateState() {
        switch state {
        case .idle:
            if isInVehicle {
                state = .drivingCandidate
                notify("Detecting driving…", "Confirming movement to start a trip.")
            }
        case .drivingCandidate:
            if !isInVehicle {
                state = .idle
                notify("Idle", "Vehicle not detected.")
            }
        case .driving, .stoppingCandidate:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locs: [CLLocation]) {
        guard let loc = locs.last, loc.horizontalAccuracy > 0 else { return }
        lastPoints.append(loc)
        if lastPoints.count > 1000 { lastPoints.removeFirst() }

        switch state {
        case .drivingCandidate:
            let recent = Array(lastPoints.suffix(12)) // ~2 min @10s
            if totalDistance(recent) > 250 {
                state = .driving
                elevateGPS()
                tripStart = loc
                tripPoints = [loc]
                notify("Trip started", "Recording route…")
            }
        case .driving:
            tripPoints.append(loc)
            if loc.speed >= 0 && loc.speed < 1.3 { // ~3 mph
                if stopCandidateBegan == nil { stopCandidateBegan = Date() }
                if let s = stopCandidateBegan, Date().timeIntervalSince(s) > 150 { // 2.5 min
                    state = .stoppingCandidate
                    notify("Possibly stopped…", "Confirming end of trip.")
                }
            } else {
                stopCandidateBegan = nil
            }
        case .stoppingCandidate:
            tripPoints.append(loc)
            if loc.speed >= 1.3 {
                state = .driving
                stopCandidateBegan = nil
                notify("Trip resumed", "Movement detected.")
            } else if let s = stopCandidateBegan, Date().timeIntervalSince(s) > 240 {
                // End trip
                endTrip(with: loc)
                lowerGPS()
                state = .idle
                stopCandidateBegan = nil
                lastPoints.removeAll()
            }
        case .idle:
            break
        }
    }

    private func endTrip(with last: CLLocation) {
        guard let start = tripStart else { return }
        let points = tripPoints + [last]
        let distance = totalDistance(points)
        let startTime = points.first?.timestamp ?? Date()
        let endTime = points.last?.timestamp ?? Date()
        // Reverse geocode
        GeoHelper.reverse(start) { startAddr in
            GeoHelper.reverse(last) { endAddr in
                let summary = TripSummary(
                    startTime: startTime,
                    endTime: endTime,
                    distanceMeters: distance,
                    startAddress: startAddr,
                    endAddress: endAddr
                )
                self.onTripClosed?(summary)
                self.notify("Trip ended", String(format: "Distance: %.1f miles", distance / 1609.344))
                self.tripPoints.removeAll()
                self.tripStart = nil
            }
        }
    }

    private func totalDistance(_ points: [CLLocation]) -> CLLocationDistance {
        guard points.count > 1 else { return 0 }
        var sum: CLLocationDistance = 0
        for i in 1..<points.count {
            sum += points[i-1].distance(from: points[i])
        }
        return sum
    }

    private func notify(_ status: String, _ detail: String?) {
        onStatusChange?(status, detail)
    }

    // MARK: CLLocationManagerDelegate
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        if manager.authorizationStatus == .authorizedAlways || manager.authorizationStatus == .authorizedWhenInUse {
            manager.startMonitoringSignificantLocationChanges()
        }
    }
}
