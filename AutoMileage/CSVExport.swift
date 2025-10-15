import Foundation
import UIKit

enum CSVExport {
    static func makeCSV(trips: [TripSummary]) -> String {
        var rows = [\"Date,Start Time,End Time,Start Address,End Address,Miles\"]
        let dfDate = DateFormatter()
        let dfTime = DateFormatter()
        dfDate.dateStyle = .short; dfDate.timeStyle = .none
        dfTime.dateStyle = .none; dfTime.timeStyle = .short

        for t in trips {
            let miles = t.distanceMeters / 1609.344
            let row = [
                dfDate.string(from: t.startTime),
                dfTime.string(from: t.startTime),
                dfTime.string(from: t.endTime),
                (t.startAddress ?? \"\"),
                (t.endAddress ?? \"\"),
                String(format: \"%.1f\", miles)
            ].map { $0.replacingOccurrences(of: \",\", with: \";\") } // naive escaping
            rows.append(row.joined(separator: \",\"))
        }
        return rows.joined(separator: \"\n\")
    }

    static func share(text: String) {
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(\"Mileage.csv\")
        try? text.data(using: .utf8)?.write(to: tmp)
        let av = UIActivityViewController(activityItems: [tmp], applicationActivities: nil)
        UIApplication.shared.firstKeyWindow?.rootViewController?.present(av, animated: true)
    }
}

extension UIApplication {
    var firstKeyWindow: UIWindow? {
        return connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow }
    }
}
