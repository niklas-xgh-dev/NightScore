import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    @Published var sleepData: [SleepEntry] = []
    @Published var isAuthorized: Bool = false
    @Published var sleepScore: Int = 0
    @Published var sleepDuration: TimeInterval = 0
    @Published var deepSleepDuration: TimeInterval = 0
    @Published var deepSleepPercentage: Double = 0
    @Published var restingHeartRate: Double = 0
    @Published var sleepEfficiency: Double = 0
    @Published var awakeInBedTime: TimeInterval = 0
    @Published var error: String?
    
    // Weekly data
    @Published var weeklyData: [DailySleepData] = []
    @Published var selectedDate: Date = Date()
    
    private let healthStore = HKHealthStore()
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    struct SleepEntry {
        let startDate: Date
        let endDate: Date
        let duration: TimeInterval
        let sleepStage: HKCategoryValueSleepAnalysis
    }
    
    struct DailySleepData: Identifiable {
        let id = UUID()
        let date: Date
        let sleepScore: Int
        let sleepData: [SleepEntry]
        let sleepDuration: TimeInterval
        let deepSleepDuration: TimeInterval
        let deepSleepPercentage: Double
        let sleepEfficiency: Double
        let restingHeartRate: Double
        let awakeInBedTime: TimeInterval
        
        var dayNumber: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "d"
            return formatter.string(from: date)
        }
        
        var dayOfWeek: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
    }
    
    init() {
        checkHealthDataAvailability()
    }
    
    private func checkHealthDataAvailability() {
        guard HKHealthStore.isHealthDataAvailable() else {
            self.error = "HealthKit is not available on this device"
            return
        }
    }
    
    func requestAuthorization(completion: @escaping (Bool) -> Void) {
        let typesToRead: Set<HKObjectType> = [
            sleepType,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { (success, error) in
            DispatchQueue.main.async {
                self.isAuthorized = success
                if let error = error {
                    self.error = "Authorization failed: \(error.localizedDescription)"
                }
                completion(success)
            }
        }
    }
    
    func fetchWeeklySleepData(completion: @escaping (Bool) -> Void) {
        guard isAuthorized else {
            self.error = "Not authorized to access HealthKit data"
            completion(false)
            return
        }
        
        // Fix: Calculate exactly 7 days
        let calendar = Calendar.current
        let now = Date()
        let endDate = now
        // Use -6 to get exactly 7 days (today plus 6 previous days)
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else {
            self.error = "Failed to calculate date range"
            completion(false)
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            
            DispatchQueue.main.async {
                if let error = error {
                    self.error = "Failed to fetch sleep data: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                    self.error = "No sleep data available for the last week"
                    completion(false)
                    return
                }
                
                self.processWeeklySleepData(sleepSamples: sleepSamples)
                
                if !self.weeklyData.isEmpty {
                    if let latestDay = self.weeklyData.first {
                        self.selectedDate = latestDay.date
                        self.updateSelectedDayData(from: latestDay)
                    }
                    completion(true)
                } else {
                    self.error = "Failed to process sleep data"
                    completion(false)
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func processWeeklySleepData(sleepSamples: [HKCategorySample]) {
        let calendar = Calendar.current
        var sleepEntriesByDay: [Date: [SleepEntry]] = [:]
        
        for sample in sleepSamples {
            if let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                let day = calendar.startOfDay(for: sample.startDate)
                
                let entry = SleepEntry(
                    startDate: sample.startDate,
                    endDate: sample.endDate,
                    duration: sample.endDate.timeIntervalSince(sample.startDate),
                    sleepStage: sleepValue
                )
                
                if sleepEntriesByDay[day] == nil {
                    sleepEntriesByDay[day] = []
                }
                
                sleepEntriesByDay[day]?.append(entry)
            }
        }
        
        var dailyDataArray: [DailySleepData] = []
        
        for (day, entries) in sleepEntriesByDay {
            let (score, duration, deepSleepPct, efficiency, awakeTime, deepSleepDuration) = calculateMetricsForDay(entries: entries)
            
            // Get resting heart rate for this day (simplified implementation)
            let heartRate = 65.0
            
            let dailyData = DailySleepData(
                date: day,
                sleepScore: score,
                sleepData: entries,
                sleepDuration: duration,
                deepSleepDuration: deepSleepDuration,
                deepSleepPercentage: deepSleepPct,
                sleepEfficiency: efficiency,
                restingHeartRate: heartRate,
                awakeInBedTime: awakeTime
            )
            
            dailyDataArray.append(dailyData)
        }
        
        // Sort by date, most recent first
        self.weeklyData = dailyDataArray.sorted { $0.date > $1.date }
    }
    
    private func calculateMetricsForDay(entries: [SleepEntry]) -> (Int, TimeInterval, Double, Double, TimeInterval, TimeInterval) {
        // Reset metrics
        var score = 0
        var totalSleep: TimeInterval = 0
        var totalInBed: TimeInterval = 0
        var awakeTime: TimeInterval = 0
        var deepSleepDuration: TimeInterval = 0
        var deepSleepPct: Double = 0
        var efficiency: Double = 0
        
        // Categories of sleep/wake
        let asleepValues: [HKCategoryValueSleepAnalysis] = [
            .asleep, .asleepCore, .asleepDeep, .asleepREM
        ]
        
        let awakeValues: [HKCategoryValueSleepAnalysis] = [
            .awake, .inBed
        ]
        
        // Calculate sleep duration
        let sleepEntries = entries.filter { asleepValues.contains($0.sleepStage) }
        totalSleep = sleepEntries.reduce(0, { $0 + $1.duration })
        
        // Calculate awake-in-bed time
        let awakeEntries = entries.filter { awakeValues.contains($0.sleepStage) }
        awakeTime = awakeEntries.reduce(0, { $0 + $1.duration })
        
        // Calculate total in-bed time
        totalInBed = totalSleep + awakeTime
        
        // Calculate deep sleep duration and percentage
        let deepSleepEntries = entries.filter { $0.sleepStage == .asleepDeep }
        deepSleepDuration = deepSleepEntries.reduce(0, { $0 + $1.duration })
        
        if totalSleep > 0 {
            deepSleepPct = (deepSleepDuration / totalSleep) * 100
        }
        
        // Calculate sleep efficiency (still tracking it even though it's not used for scoring)
        if totalInBed > 0 {
            efficiency = (totalSleep / totalInBed) * 100
        }
        
        // UPDATED SCORING SYSTEM
        
        // 1. Sleep Duration Score (50% of total, 50 points maximum)
        let durationHours = totalSleep / 3600
        var durationScore = 0
        
        if durationHours >= 8 {
            durationScore = 50  // Full points for 8+ hours
        } else if durationHours >= 7 {
            durationScore = 40  // Good score for 7-8 hours
        } else if durationHours >= 6 {
            durationScore = 30  // Ok score for 6-7 hours
        } else if durationHours >= 5 {
            durationScore = 20  // Lower score for 5-6 hours
        } else {
            durationScore = 10  // Minimal score for less than 5 hours
        }
        
        // 2. Deep Sleep Percentage Score (50% of total, 50 points maximum)
        var deepSleepScore = 0
        
        if deepSleepPct >= 12 {
            deepSleepScore = 50  // Full points for 12%+ deep sleep
        } else if deepSleepPct >= 10 {
            deepSleepScore = 40  // Good score for 10-12% deep sleep
        } else if deepSleepPct >= 8 {
            deepSleepScore = 30  // Ok score for 8-10% deep sleep
        } else if deepSleepPct >= 5 {
            deepSleepScore = 20  // Lower score for 5-8% deep sleep
        } else {
            deepSleepScore = 10  // Minimal score for less than 5% deep sleep
        }
        
        // Calculate total score (just two components now)
        score = durationScore + deepSleepScore
        
        // Ensure score is in range 1-100
        score = max(1, min(100, score))
        
        return (score, totalSleep, deepSleepPct, efficiency, awakeTime, deepSleepDuration)
    }
    
    func updateSelectedDayData(date: Date) {
        if let dayData = weeklyData.first(where: { Calendar.current.isDate($0.date, inSameDayAs: date) }) {
            self.selectedDate = date
            updateSelectedDayData(from: dayData)
        }
    }
    
    private func updateSelectedDayData(from dayData: DailySleepData) {
        self.sleepData = dayData.sleepData
        self.sleepScore = dayData.sleepScore
        self.sleepDuration = dayData.sleepDuration
        self.deepSleepDuration = dayData.deepSleepDuration
        self.deepSleepPercentage = dayData.deepSleepPercentage
        self.sleepEfficiency = dayData.sleepEfficiency
        self.restingHeartRate = dayData.restingHeartRate
        self.awakeInBedTime = dayData.awakeInBedTime
    }
    
    func fetchLastNightSleepData(completion: @escaping (Bool) -> Void) {
        fetchWeeklySleepData(completion: completion)
    }
}
