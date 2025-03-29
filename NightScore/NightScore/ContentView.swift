import SwiftUI
import HealthKit

struct ContentView: View {
    @StateObject private var healthKitManager = HealthKitManager()
    @State private var isLoading: Bool = false
    @State private var showError: Bool = false
    
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
                        Image(systemName: "bed.double.fill")
                            .font(.system(size: 80))
                            .foregroundColor(.blue)
                        
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
                    // Sleep score display
                    scoreView
                    
                    // Details card
                    detailsCard
                        .padding()
                    
                    // Refresh button
                    Button("Analyze Last Night's Sleep") {
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
        
        healthKitManager.fetchLastNightSleepData { success in
            isLoading = false
            
            if !success {
                showError = true
            }
        }
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