import Foundation
import HealthKit

class HealthKitManager: ObservableObject {
    @Published var sleepData: [SleepEntry] = []
    @Published var isAuthorized: Bool = false
    @Published var sleepScore: Int = 0
    @Published var sleepDuration: TimeInterval = 0
    @Published var deepSleepPercentage: Double = 0
    @Published var restingHeartRate: Double = 0
    @Published var sleepEfficiency: Double = 0
    @Published var error: String?
    
    // New properties for weekly data
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
    
    // New structure to hold daily sleep data
    struct DailySleepData: Identifiable {
        let id = UUID()
        let date: Date
        let sleepScore: Int
        let sleepData: [SleepEntry]
        let sleepDuration: TimeInterval
        let deepSleepPercentage: Double
        let sleepEfficiency: Double
        let restingHeartRate: Double
        
        // Format the date to display day of week and day number
        var formattedDate: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE\ndd"
            return formatter.string(from: date)
        }
        
        // Day of month only
        var dayNumber: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "d"
            return formatter.string(from: date)
        }
        
        // Day of week only
        var dayOfWeek: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        }
        
        // Check if this entry is for today or a specific date
        func isDate(_ compareDate: Date) -> Bool {
            return Calendar.current.isDate(date, inSameDayAs: compareDate)
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
        // Define the health data types we want to read
        let typesToRead: Set<HKObjectType> = [
            sleepType,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!,
            HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
        ]
        
        // Request authorization
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
    
    // New function to fetch last 7 days of sleep data
    func fetchWeeklySleepData(completion: @escaping (Bool) -> Void) {
        guard isAuthorized else {
            self.error = "Not authorized to access HealthKit data"
            completion(false)
            return
        }
        
        // Calculate date range for the last 7 days
        let calendar = Calendar.current
        let now = Date()
        let endDate = calendar.startOfDay(for: now)
        guard let startDate = calendar.date(byAdding: .day, value: -7, to: endDate) else {
            self.error = "Failed to calculate date range"
            completion(false)
            return
        }
        
        // Create a predicate for the last 7 days
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: now, options: .strictStartDate)
        
        // Query parameters
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        // Execute the query to get all sleep samples for the week
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
                
                // Group samples by day
                self.processWeeklySleepData(sleepSamples: sleepSamples)
                
                // If we got data and processed it successfully
                if !self.weeklyData.isEmpty {
                    // Set the selected date to the most recent day with data
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
    
    // Process sleep samples and group by day
    private func processWeeklySleepData(sleepSamples: [HKCategorySample]) {
        let calendar = Calendar.current
        var sleepEntriesByDay: [Date: [SleepEntry]] = [:]
        
        // First, group all samples by day
        for sample in sleepSamples {
            if let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                // Get the day component (start of day) for the sleep entry
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
        
        // Now process each day's data
        var dailyDataArray: [DailySleepData] = []
        
        for (day, entries) in sleepEntriesByDay {
            // Calculate metrics for this day
            let (score, duration, deepSleepPct, efficiency) = calculateMetricsForDay(entries: entries)
            
            // Get resting heart rate for this day (simplified - would need more accurate implementation)
            let heartRate = 65.0 // Placeholder - you'd want to fetch the actual value
            
            let dailyData = DailySleepData(
                date: day,
                sleepScore: score,
                sleepData: entries,
                sleepDuration: duration,
                deepSleepPercentage: deepSleepPct,
                sleepEfficiency: efficiency,
                restingHeartRate: heartRate
            )
            
            dailyDataArray.append(dailyData)
        }
        
        // Sort by date, most recent first
        let sortedData = dailyDataArray.sorted { $0.date > $1.date }
        self.weeklyData = sortedData
    }
    
    // Calculate sleep metrics for a given day
    private func calculateMetricsForDay(entries: [SleepEntry]) -> (Int, TimeInterval, Double, Double) {
        // Reset metrics
        var score = 0
        var totalSleep: TimeInterval = 0
        var deepSleepPct: Double = 0
        var efficiency: Double = 0
        
        // Filter for actual sleep (not in bed but awake)
        let asleepValues: [HKCategoryValueSleepAnalysis] = [
            .asleep,
            .inBed,
            .asleepCore,
            .asleepDeep,
            .asleepREM
        ]
        
        let sleepEntries = entries.filter { asleepValues.contains($0.sleepStage) }
        
        // Calculate total duration
        for entry in sleepEntries {
            totalSleep += entry.duration
        }
        
        // Calculate deep sleep duration and percentage
        let deepSleepEntries = entries.filter { $0.sleepStage == .asleepDeep }
        let deepSleepDuration = deepSleepEntries.reduce(0) { $0 + $1.duration }
        
        if totalSleep > 0 {
            deepSleepPct = (deepSleepDuration / totalSleep) * 100
        }
        
        // Calculate sleep efficiency
        let inBedEntries = entries.filter { $0.sleepStage == .inBed || $0.sleepStage == .asleep || 
                                         $0.sleepStage == .asleepCore || $0.sleepStage == .asleepDeep || 
                                         $0.sleepStage == .asleepREM }
        let totalInBedDuration = inBedEntries.reduce(0) { $0 + $1.duration }
        
        if totalInBedDuration > 0 {
            efficiency = (totalSleep / totalInBedDuration) * 100
        }
        
        // Score calculation based on duration (weight: 40%)
        // Ideal sleep duration: 7-9 hours
        let durationHours = totalSleep / 3600
        var durationScore = 0
        
        if durationHours >= 7 && durationHours <= 9 {
            durationScore = 40  // Optimal sleep duration
        } else if durationHours >= 6 && durationHours < 7 {
            durationScore = 30  // Slightly below optimal
        } else if durationHours > 9 && durationHours <= 10 {
            durationScore = 30  // Slightly above optimal
        } else if durationHours >= 5 && durationHours < 6 {
            durationScore = 20  // Insufficient sleep
        } else if durationHours > 10 {
            durationScore = 20  // Too much sleep
        } else {
            durationScore = 10  // Very insufficient sleep
        }
        
        // Deep sleep percentage score (weight: 30%)
        // Ideal deep sleep: 20-25% of total sleep
        var deepSleepScore = 0
        
        if deepSleepPct >= 20 && deepSleepPct <= 25 {
            deepSleepScore = 30  // Optimal deep sleep
        } else if (deepSleepPct >= 15 && deepSleepPct < 20) || (deepSleepPct > 25 && deepSleepPct <= 30) {
            deepSleepScore = 25  // Near optimal
        } else if (deepSleepPct >= 10 && deepSleepPct < 15) || (deepSleepPct > 30 && deepSleepPct <= 35) {
            deepSleepScore = 15  // Suboptimal
        } else {
            deepSleepScore = 10  // Poor deep sleep pattern
        }
        
        // Sleep efficiency score (weight: 30%)
        // Ideal efficiency: >= 85%
        var efficiencyScore = 0
        
        if efficiency >= 90 {
            efficiencyScore = 30  // Excellent efficiency
        } else if efficiency >= 85 && efficiency < 90 {
            efficiencyScore = 25  // Good efficiency
        } else if efficiency >= 75 && efficiency < 85 {
            efficiencyScore = 20  // Average efficiency
        } else if efficiency >= 65 && efficiency < 75 {
            efficiencyScore = 15  // Below average efficiency
        } else {
            efficiencyScore = 10  // Poor efficiency
        }
        
        // Calculate total score
        score = durationScore + deepSleepScore + efficiencyScore
        
        // Ensure score is in range 1-100
        score = max(1, min(100, score))
        
        return (score, totalSleep, deepSleepPct, efficiency)
    }
    
    // Update the current display data with the selected day's data
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
        self.deepSleepPercentage = dayData.deepSleepPercentage
        self.sleepEfficiency = dayData.sleepEfficiency
        self.restingHeartRate = dayData.restingHeartRate
    }
    
    // Keep existing function for compatibility - now calls the weekly function and selects the most recent day
    func fetchLastNightSleepData(completion: @escaping (Bool) -> Void) {
        fetchWeeklySleepData { success in
            // If successful, data for most recent night will be selected automatically
            completion(success)
        }
    }
    
    // Existing functions kept for compatibility
    private func fetchRestingHeartRate() {
        guard isAuthorized else { return }
        
        // This is a simplified implementation that would need more development
        // for a production app. It just gets the most recent resting heart rate.
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!
        
        let query = HKStatisticsQuery(
            quantityType: heartRateType,
            quantitySamplePredicate: nil,
            options: .discreteAverage
        ) { _, result, error in
            DispatchQueue.main.async {
                guard let result = result, let averageValue = result.averageQuantity() else {
                    self.restingHeartRate = 0
                    return
                }
                
                let heartRateUnit = HKUnit.count().unitDivided(by: HKUnit.minute())
                self.restingHeartRate = averageValue.doubleValue(for: heartRateUnit)
            }
        }
        
        healthStore.execute(query)
    }
}