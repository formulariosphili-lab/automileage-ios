import Foundation
import CoreLocation

enum GeoHelper {
    static let geocoder = CLGeocoder()

    static func reverse(_ loc: CLLocation, completion: @escaping (String?) -> Void) {
        geocoder.reverseGeocodeLocation(loc) { placemarks, error in
            guard let p = placemarks?.first, error == nil else {
                completion(nil); return
            }
            var parts: [String] = []
            if let s = p.name { parts.append(s) }
            if let c = p.locality { parts.append(c) }
            if let a = p.administrativeArea { parts.append(a) }
            completion(parts.joined(separator: ", "))
        }
    }
}
