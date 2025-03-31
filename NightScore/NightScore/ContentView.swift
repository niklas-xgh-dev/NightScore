import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    @State private var showingWeeklyView: Bool = true
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView()
                        .scaleEffect(2)
                        .padding()
                    Text("Analyzing your sleep data...")
                        .padding()
                } else if !healthKitManager.isAuthorized {
                    VStack(spacing: 20) {
                        Image("AppLogo")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                        
                        Text("NightScore needs access to your Health data")
                            .font(.title2)
                            .multilineTextAlignment(.center)
                        
                        Text("This app uses your sleep data to calculate a sleep quality score.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                        
                        Button("Authorize HealthKit Access") {
                            requestHealthKitAuthorization()
                        }
                        .padding()
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                    .padding()
                } else {
                    // Toggle button for weekly/daily view
                    HStack {
                        Spacer()
                        Button(action: {
                            withAnimation {
                                showingWeeklyView.toggle()
                            }
                        }) {
                            Text(showingWeeklyView ? "Daily View" : "Weekly View")
                                .font(.subheadline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .padding(.trailing)
                    }
                    
                    if showingWeeklyView {
                        // Weekly overview
                        weeklyView
                    } else {
                        // Daily detail view
                        dailyView
                    }
                    
                    // Refresh button
                    Button("Update Sleep Data") {
                        fetchSleepData()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .padding(.top, 10)
                }
            }
            .padding()
            .onAppear {
                if !healthKitManager.isAuthorized {
                    requestHealthKitAuthorization()
                } else {
                    fetchSleepData()
                }
            }
            .alert(isPresented: $showError) {
                Alert(
                    title: Text("Error"),
                    message: Text(healthKitManager.error ?? "An unknown error occurred"),
                    dismissButton: .default(Text("OK"))
                )
            }
            .navigationTitle("NightScore")
        }
    }
    
    // Weekly overview showing last 7 days
    var weeklyView: some View {
        VStack {
            Text("7-Day Sleep Overview")
                .font(.headline)
                .padding(.top)
            
            if healthKitManager.weeklyData.isEmpty {
                Text("No sleep data available for the past week")
                    .foregroundColor(.secondary)
                    .padding()
            } else {
                // Weekly chart in grid layout (4 in top row, 3 in bottom row)
                VStack(spacing: 15) {
                    // First row (4 days)
                    HStack(spacing: 15) {
                        ForEach(Array(healthKitManager.weeklyData.prefix(4))) { day in
                            DaySleepCard(day: day, isSelected: Calendar.current.isDate(day.date, inSameDayAs: healthKitManager.selectedDate))
                                .onTapGesture {
                                    healthKitManager.updateSelectedDayData(date: day.date)
                                    withAnimation {
                                        showingWeeklyView = false
                                    }
                                }
                                .frame(maxWidth: .infinity)
                        }
                    }
                    
                    // Second row (3 days)
                    HStack(spacing: 15) {
                        ForEach(Array(healthKitManager.weeklyData.suffix(from: min(4, healthKitManager.weeklyData.count)))) { day in
                            DaySleepCard(day: day, isSelected: Calendar.current.isDate(day.date, inSameDayAs: healthKitManager.selectedDate))
                                .onTapGesture {
                                    healthKitManager.updateSelectedDayData(date: day.date)
                                    withAnimation {
                                        showingWeeklyView = false
                                    }
                                }
                                .frame(maxWidth: .infinity)
                        }
                        
                        // Add spacers for the empty slots in the second row to maintain layout
                        if healthKitManager.weeklyData.count > 4 {
                            let emptySlots = max(0, 7 - healthKitManager.weeklyData.count)
                            ForEach(0..<emptySlots, id: \.self) { _ in
                                Spacer()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Summary statistics
                WeeklySummaryView(weeklyData: healthKitManager.weeklyData)
            }
        }
    }
    
    // Daily detail view (similar to original design)
    var dailyView: some View {
        VStack {
            // Date header
            HStack {
                VStack(alignment: .leading) {
                    Text("Sleep Score for")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Text(formattedDate(healthKitManager.selectedDate))
                        .font(.headline)
                }
                
                Spacer()
            }
            .padding(.horizontal)
            
            // Sleep score display
            scoreView
            
            // Details card
            detailsCard
                .padding()
        }
    }
    
    var scoreView: some View {
        ZStack {
            Circle()
                .stroke(
                    Color.blue.opacity(0.2),
                    lineWidth: 15
                )
            
            Circle()
                .trim(from: 0, to: CGFloat(healthKitManager.sleepScore) / 100)
                .stroke(
                    scoreColor(),
                    style: StrokeStyle(
                        lineWidth: 15,
                        lineCap: .round
                    )
                )
                .rotationEffect(.degrees(-90))
            
            VStack {
                Text("\(healthKitManager.sleepScore)")
                    .font(.system(size: 80, weight: .bold))
                Text("Sleep Score")
                    .font(.headline)
            }
        }
        .frame(width: 250, height: 250)
        .padding()
    }
    
    var detailsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Sleep Details")
                .font(.headline)
                .padding(.bottom, 5)
            
            DetailRow(
                icon: "clock.fill",
                title: "Sleep Duration",
                value: formatDuration(healthKitManager.sleepDuration)
            )
            
            DetailRow(
                icon: "waveform.path.ecg",
                title: "Deep Sleep",
                value: String(format: "%.1f%%", healthKitManager.deepSleepPercentage)
            )
            
            DetailRow(
                icon: "chart.bar.fill",
                title: "Sleep Efficiency",
                value: String(format: "%.1f%%", healthKitManager.sleepEfficiency)
            )
            
            if healthKitManager.restingHeartRate > 0 {
                DetailRow(
                    icon: "heart.fill",
                    title: "Resting Heart Rate",
                    value: String(format: "%.0f bpm", healthKitManager.restingHeartRate)
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    func scoreColor() -> Color {
        if healthKitManager.sleepScore >= 80 {
            return Color.green
        } else if healthKitManager.sleepScore >= 60 {
            return Color.yellow
        } else {
            return Color.red
        }
    }
    
    func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
    
    func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        return "\(hours) hr \(minutes) min"
    }
    
    func requestHealthKitAuthorization() {
        isLoading = true
        
        healthKitManager.requestAuthorization { success in
            isLoading = false
            
            if !success {
                showError = true
            } else if success {
                fetchSleepData()
            }
        }
    }
    
    func fetchSleepData() {
        isLoading = true
        
        healthKitManager.fetchWeeklySleepData { success in
            isLoading = false
            
            if !success {
                showError = true
            }
        }
    }
}

// Card view for each day in the weekly overview
struct DaySleepCard: View {
    let day: HealthKitManager.DailySleepData
    let isSelected: Bool
    
    var body: some View {
        VStack {
            // Sleep score circle
            ZStack {
                Circle()
                    .stroke(Color.blue.opacity(0.2), lineWidth: 4)
                    .frame(width: 60, height: 60)
                
                Circle()
                    .trim(from: 0, to: CGFloat(day.sleepScore) / 100)
                    .stroke(scoreColor(day.sleepScore), style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(-90))
                
                Text("\(day.sleepScore)")
                    .font(.system(size: 20, weight: .bold))
            }
            
            // Day of week and date
            Text(day.dayOfWeek)
                .font(.caption)
                .fontWeight(.medium)
            
            Text(day.dayNumber)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            // Sleep duration
            Text(formatHours(day.sleepDuration))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 5)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(10)
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
        )
        .frame(minWidth: 70)
    }
    
    private func scoreColor(_ score: Int) -> Color {
        if score >= 80 {
            return Color.green
        } else if score >= 60 {
            return Color.yellow
        } else {
            return Color.red
        }
    }
    
    private func formatHours(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// Summary statistics for the weekly view
struct WeeklySummaryView: View {
    let weeklyData: [HealthKitManager.DailySleepData]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            Text("Weekly Summary")
                .font(.headline)
                .padding(.bottom, 5)
            
            HStack(spacing: 30) {
                VStack(alignment: .leading) {
                    SummaryItem(
                        icon: "star.fill", 
                        title: "Average Score", 
                        value: String(format: "%.0f", averageSleepScore)
                    )
                    
                    SummaryItem(
                        icon: "clock.fill", 
                        title: "Avg. Duration", 
                        value: formatDuration(averageSleepDuration)
                    )
                }
                
                VStack(alignment: .leading) {
                    SummaryItem(
                        icon: "waveform.path.ecg", 
                        title: "Avg. Deep Sleep", 
                        value: String(format: "%.1f%%", averageDeepSleep)
                    )
                    
                    SummaryItem(
                        icon: "chart.bar.fill", 
                        title: "Avg. Efficiency", 
                        value: String(format: "%.1f%%", averageEfficiency)
                    )
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var averageSleepScore: Double {
        guard !weeklyData.isEmpty else { return 0 }
        let sum = weeklyData.reduce(0) { $0 + Double($1.sleepScore) }
        return sum / Double(weeklyData.count)
    }
    
    private var averageSleepDuration: TimeInterval {
        guard !weeklyData.isEmpty else { return 0 }
        let sum = weeklyData.reduce(0) { $0 + $1.sleepDuration }
        return sum / Double(weeklyData.count)
    }
    
    private var averageDeepSleep: Double {
        guard !weeklyData.isEmpty else { return 0 }
        let sum = weeklyData.reduce(0) { $0 + $1.deepSleepPercentage }
        return sum / Double(weeklyData.count)
    }
    
    private var averageEfficiency: Double {
        guard !weeklyData.isEmpty else { return 0 }
        let sum = weeklyData.reduce(0) { $0 + $1.sleepEfficiency }
        return sum / Double(weeklyData.count)
    }
    
    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        
        return "\(hours)h \(minutes)m"
    }
}

// Helper view for summary items
struct SummaryItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            VStack(alignment: .leading) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
        .padding(.vertical, 4)
    }
}

struct DetailRow: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 25)
            Text(title)
                .foregroundColor(.primary)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
                .fontWeight(.semibold)
        }
    }
}