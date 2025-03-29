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
    
    private let healthStore = HKHealthStore()
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    struct SleepEntry {
        let startDate: Date
        let endDate: Date
        let duration: TimeInterval
        let sleepStage: HKCategoryValueSleepAnalysis
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
    
    func fetchLastNightSleepData(completion: @escaping (Bool) -> Void) {
        guard isAuthorized else {
            self.error = "Not authorized to access HealthKit data"
            completion(false)
            return
        }
        
        // Calculate the date range for last night (yesterday evening to this morning)
        let now = Date()
        let calendar = Calendar.current
        
        // Start from yesterday evening (8 PM)
        let startOfYesterday = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now)!)
        let yesterdayEvening = calendar.date(bySettingHour: 20, minute: 0, second: 0, of: startOfYesterday)!
        
        // End at this morning (10 AM)
        let endTime = calendar.date(bySettingHour: 10, minute: 0, second: 0, of: now)!
        
        let predicate = HKQuery.predicateForSamples(withStart: yesterdayEvening, end: endTime, options: .strictStartDate)
        
        // Query parameters
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        // Execute the query
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (query, samples, error) in
            
            DispatchQueue.main.async {
                if let error = error {
                    self.error = "Failed to fetch sleep data: \(error.localizedDescription)"
                    completion(false)
                    return
                }
                
                guard let sleepSamples = samples as? [HKCategorySample] else {
                    self.error = "No sleep data available"
                    completion(false)
                    return
                }
                
                // Process sleep data
                var entries: [SleepEntry] = []
                
                for sample in sleepSamples {
                    if let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value) {
                        let entry = SleepEntry(
                            startDate: sample.startDate,
                            endDate: sample.endDate,
                            duration: sample.endDate.timeIntervalSince(sample.startDate),
                            sleepStage: sleepValue
                        )
                        entries.append(entry)
                    }
                }
                
                self.sleepData = entries
                
                // If we got data, calculate the sleep score
                if !entries.isEmpty {
                    self.calculateSleepScore()
                    completion(true)
                } else {
                    self.error = "No sleep data found for last night"
                    completion(false)
                }
            }
        }
        
        healthStore.execute(query)
    }
    
    private func calculateSleepScore() {
        // Reset the score
        var score = 0
        
        // 1. Calculate total sleep duration
        let totalSleep = calculateTotalSleepDuration()
        self.sleepDuration = totalSleep
        
        // 2. Calculate deep sleep percentage
        let deepSleep = calculateDeepSleepPercentage()
        self.deepSleepPercentage = deepSleep
        
        // 3. Get sleep efficiency
        let efficiency = calculateSleepEfficiency()
        self.sleepEfficiency = efficiency
        
        // 4. Get resting heart rate during sleep (simplified)
        fetchRestingHeartRate()
        
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
        
        if deepSleep >= 20 && deepSleep <= 25 {
            deepSleepScore = 30  // Optimal deep sleep
        } else if (deepSleep >= 15 && deepSleep < 20) || (deepSleep > 25 && deepSleep <= 30) {
            deepSleepScore = 25  // Near optimal
        } else if (deepSleep >= 10 && deepSleep < 15) || (deepSleep > 30 && deepSleep <= 35) {
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
        
        self.sleepScore = score
    }
    
    private func calculateTotalSleepDuration() -> TimeInterval {
        // Filter for actual sleep (not in bed but awake)
        let asleepValues: [HKCategoryValueSleepAnalysis] = [
            .asleep,
            .inBed,
            .asleepCore,
            .asleepDeep,
            .asleepREM
        ]
        
        let sleepEntries = sleepData.filter { asleepValues.contains($0.sleepStage) }
        
        // Calculate total duration
        var totalDuration: TimeInterval = 0
        for entry in sleepEntries {
            totalDuration += entry.duration
        }
        
        return totalDuration
    }
    
    private func calculateDeepSleepPercentage() -> Double {
        let totalSleepDuration = calculateTotalSleepDuration()
        guard totalSleepDuration > 0 else { return 0 }
        
        // Calculate deep sleep duration
        let deepSleepEntries = sleepData.filter { $0.sleepStage == .asleepDeep }
        let deepSleepDuration = deepSleepEntries.reduce(0) { $0 + $1.duration }
        
        // Calculate percentage
        return (deepSleepDuration / totalSleepDuration) * 100
    }
    
    private func calculateSleepEfficiency() -> Double {
        // Time in bed
        let inBedEntries = sleepData.filter { $0.sleepStage == .inBed || $0.sleepStage == .asleep || 
                                           $0.sleepStage == .asleepCore || $0.sleepStage == .asleepDeep || 
                                           $0.sleepStage == .asleepREM }
        let totalInBedDuration = inBedEntries.reduce(0) { $0 + $1.duration }
        
        // Actual sleep time
        let actualSleepDuration = calculateTotalSleepDuration()
        
        // Calculate efficiency
        guard totalInBedDuration > 0 else { return 0 }
        return (actualSleepDuration / totalInBedDuration) * 100
    }
    
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