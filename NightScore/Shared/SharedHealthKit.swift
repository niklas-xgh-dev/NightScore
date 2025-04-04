import Foundation
import HealthKit

// Shared sleep data structure for both app and widget
struct SharedSleepData: Codable {
    let date: Date
    let sleepScore: Int
    let sleepDuration: TimeInterval
    
    var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: date)
    }
    
    func formatHours() -> String {
        let hours = Int(sleepDuration) / 3600
        let minutes = (Int(sleepDuration) % 3600) / 60
        
        return "\(hours)h \(minutes)m"
    }
    
    // Create from your app's DailySleepData
    static func fromDailySleepData(_ data: HealthKitManager.DailySleepData) -> SharedSleepData {
        return SharedSleepData(
            date: data.date,
            sleepScore: data.sleepScore,
            sleepDuration: data.sleepDuration
        )
    }
}

// Utility for sharing data between app and widget
class SharedDefaults {
    static let appGroupIdentifier = "group.com.yourcompany.nightscore"
    
    static let defaults = UserDefaults(suiteName: appGroupIdentifier)
    
    static func saveWeeklyData(_ data: [SharedSleepData]) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(data) {
            defaults?.set(encoded, forKey: "weeklyData")
            defaults?.set(Date(), forKey: "lastUpdate")
        }
    }
    
    static func loadWeeklyData() -> [SharedSleepData]? {
        guard let data = defaults?.data(forKey: "weeklyData") else {
            return nil
        }
        
        let decoder = JSONDecoder()
        return try? decoder.decode([SharedSleepData].self, from: data)
    }
    
    static func lastUpdateTime() -> Date? {
        return defaults?.object(forKey: "lastUpdate") as? Date
    }
}

// Extension for HealthKitManager - placed at file scope
#if canImport(WidgetKit)
import WidgetKit
#endif

extension HealthKitManager {
    func saveDataForWidget() {
        // Convert from DailySleepData to SharedSleepData
        let sharedData = self.weeklyData.map { dayData in
            SharedSleepData.fromDailySleepData(dayData)
        }
        
        // Save to shared defaults
        SharedDefaults.saveWeeklyData(sharedData)
        
        // Request widget refresh if WidgetKit is available
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}