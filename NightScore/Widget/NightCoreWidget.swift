import WidgetKit
import SwiftUI
import HealthKit

struct Provider: TimelineProvider {
    let healthKitManager = HealthKitWidget()
    
    func placeholder(in context: Context) -> SleepScoreEntry {
        SleepScoreEntry(date: Date(), weeklyData: SleepScoreEntry.sampleData)
    }

    func getSnapshot(in context: Context, completion: @escaping (SleepScoreEntry) -> ()) {
        // First try to load data from shared defaults
        if let sharedData = SharedDefaults.loadWeeklyData() {
            let entry = SleepScoreEntry(date: Date(), weeklyData: sharedData)
            completion(entry)
            return
        }
        
        // If no shared data or it's stale, use sample data for the snapshot
        let entry = SleepScoreEntry(date: Date(), weeklyData: SleepScoreEntry.sampleData)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<Entry>) -> ()) {
        // First check if we have recent data from the main app
        if let sharedData = SharedDefaults.loadWeeklyData(),
           let lastUpdate = SharedDefaults.lastUpdateTime(),
           Date().timeIntervalSince(lastUpdate) < 3600 { // Less than an hour old
            
            let entry = SleepScoreEntry(date: Date(), weeklyData: sharedData)
            let nextUpdate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date().addingTimeInterval(3600)
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            
            completion(timeline)
            return
        }
        
        // Otherwise fetch data directly from HealthKit
        healthKitManager.fetchWeeklySleepData { weeklyData in
            let currentDate = Date()
            let entry = SleepScoreEntry(date: currentDate, weeklyData: weeklyData)
            
            // Update at 4am or in 8 hours, whichever comes first
            var nextUpdateComponents = DateComponents()
            nextUpdateComponents.hour = 4
            nextUpdateComponents.minute = 0
            
            let calendar = Calendar.current
            let now = currentDate
            var nextUpdate = calendar.nextDate(after: now, matching: nextUpdateComponents, matchingPolicy: .nextTime) ?? now.addingTimeInterval(8 * 3600)
            
            // If next 4am is more than 8 hours away, update in 8 hours
            if nextUpdate.timeIntervalSince(now) > 8 * 3600 {
                nextUpdate = now.addingTimeInterval(8 * 3600)
            }
            
            let timeline = Timeline(entries: [entry], policy: .after(nextUpdate))
            completion(timeline)
        }
    }
}

struct SleepScoreEntry: TimelineEntry {
    let date: Date
    let weeklyData: [SharedSleepData]
    
    static var sampleData: [SharedSleepData] {
        let calendar = Calendar.current
        let today = Date()
        
        return (0..<7).map { dayOffset in
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else {
                return SharedSleepData(date: today, sleepScore: 70, sleepDuration: 25200) // 7 hours
            }
            
            // Create more varied sample data
            let score = [85, 72, 68, 90, 76, 65, 82][dayOffset % 7]
            let duration = Double([7.5, 6.2, 6.8, 8.1, 7.0, 5.5, 7.8][dayOffset % 7]) * 3600
            
            return SharedSleepData(date: date, sleepScore: score, sleepDuration: duration)
        }
    }
}

class HealthKitWidget {
    private let healthStore = HKHealthStore()
    private let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis)!
    
    init() {
        requestAuthorization()
    }
    
    private func requestAuthorization() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        
        let typesToRead: Set<HKObjectType> = [
            sleepType,
            HKObjectType.quantityType(forIdentifier: .heartRate)!,
            HKObjectType.quantityType(forIdentifier: .restingHeartRate)!
        ]
        
        healthStore.requestAuthorization(toShare: nil, read: typesToRead) { _, _ in }
    }
    
    func fetchWeeklySleepData(completion: @escaping ([SharedSleepData]) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion([])
            return
        }
        
        let calendar = Calendar.current
        let now = Date()
        let endDate = now
        guard let startDate = calendar.date(byAdding: .day, value: -6, to: calendar.startOfDay(for: now)) else {
            completion([])
            return
        }
        
        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
        
        let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { (_, samples, error) in
            
            guard error == nil, let sleepSamples = samples as? [HKCategorySample], !sleepSamples.isEmpty else {
                DispatchQueue.main.async {
                    completion([])
                }
                return
            }
            
            let weeklyData = self.processWeeklySleepData(sleepSamples: sleepSamples)
            
            DispatchQueue.main.async {
                completion(weeklyData)
            }
        }
        
        healthStore.execute(query)
    }
    
    private func processWeeklySleepData(sleepSamples: [HKCategorySample]) -> [SharedSleepData] {
        let calendar = Calendar.current
        var sleepByDay: [Date: [HKCategorySample]] = [:]
        
        for sample in sleepSamples {
            let day = calendar.startOfDay(for: sample.startDate)
            
            if sleepByDay[day] == nil {
                sleepByDay[day] = []
            }
            
            sleepByDay[day]?.append(sample)
        }
        
        var dailyDataArray: [SharedSleepData] = []
        
        for (day, samples) in sleepByDay {
            let (score, duration) = calculateMetricsForDay(samples: samples)
            
            let dailyData = SharedSleepData(
                date: day,
                sleepScore: score,
                sleepDuration: duration
            )
            
            dailyDataArray.append(dailyData)
        }
        
        // Sort by date, most recent first
        return dailyDataArray.sorted { $0.date > $1.date }
    }
    
    private func calculateMetricsForDay(samples: [HKCategorySample]) -> (Int, TimeInterval) {
        var totalSleep: TimeInterval = 0
        
        // Categories of sleep
        let asleepValues: [HKCategoryValueSleepAnalysis] = [
            .asleep, .asleepCore, .asleepDeep, .asleepREM
        ]
        
        // Calculate sleep duration
        for sample in samples {
            if let sleepValue = HKCategoryValueSleepAnalysis(rawValue: sample.value),
               asleepValues.contains(sleepValue) {
                totalSleep += sample.endDate.timeIntervalSince(sample.startDate)
            }
        }
        
        // Basic scoring algorithm - simplified for the widget
        let durationHours = totalSleep / 3600
        var score = 0
        
        if durationHours >= 8 {
            score = 90  // Great
        } else if durationHours >= 7 {
            score = 80  // Good
        } else if durationHours >= 6 {
            score = 70  // Okay
        } else if durationHours >= 5 {
            score = 60  // Low
        } else {
            score = 50  // Poor
        }
        
        // Add some randomness for variety (you'd remove this in production)
        score += Int.random(in: -5...5)
        score = max(1, min(100, score))
        
        return (score, totalSleep)
    }
}

struct NightScoreWidgetEntryView : View {
    var entry: Provider.Entry
    
    var body: some View {
        ZStack {
            Color(UIColor.systemBackground)
            
            VStack(spacing: 8) {
                // Header with app name
                HStack {
                    Text("NightScore")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Main content - weekly sleep score circles
                HStack(spacing: 10) {
                    // Display up to 7 days
                    ForEach(Array(entry.weeklyData.prefix(7).enumerated()), id: \.element.date) { index, day in
                        VStack(spacing: 3) {
                            // Sleep score circle
                            ScoreCircle(score: day.sleepScore, size: 36)
                            
                            // Day of week
                            Text(day.dayOfWeek)
                                .font(.system(size: 9))
                                .fontWeight(.medium)
                            
                            // Sleep duration
                            Text(day.formatHours())
                                .font(.system(size: 8))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .padding(.bottom, 8)
        }
    }
}

struct ScoreCircle: View {
    let score: Int
    let size: CGFloat
    
    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.blue.opacity(0.2), lineWidth: max(2, size/20))
                .frame(width: size, height: size)
            
            Circle()
                .trim(from: 0, to: CGFloat(score) / 100)
                .stroke(
                    scoreColor(),
                    style: StrokeStyle(lineWidth: max(2, size/20), lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .frame(width: size, height: size)
            
            Text("\(score)")
                .font(.system(size: size/2.5, weight: .bold))
                .foregroundColor(scoreColor())
        }
    }
    
    func scoreColor() -> Color {
        if score >= 80 {
            return Color.green
        } else if score >= 60 {
            return Color.yellow
        } else {
            return Color.red
        }
    }
}

// IMPORTANT: We're NOT adding the @main attribute here
// because it already exists in the main app
struct NightScoreWidget: Widget {
    let kind: String = "NightScoreWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            NightScoreWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("NightScore")
        .description("View your recent sleep quality scores")
        .supportedFamilies([.systemMedium]) // Only support medium size
    }
}

struct NightScoreWidget_Previews: PreviewProvider {
    static var previews: some View {
        NightScoreWidgetEntryView(entry: SleepScoreEntry(date: Date(), weeklyData: SleepScoreEntry.sampleData))
            .previewContext(WidgetPreviewContext(family: .systemMedium))
    }
}