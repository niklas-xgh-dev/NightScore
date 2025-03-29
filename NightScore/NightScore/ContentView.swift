import SwiftUI

struct ContentView: View {
    @State private var sleepScore: Int = 85
    @State private var isLoading: Bool = false
    
    var body: some View {
        VStack {
            if isLoading {
                ProgressView()
                    .scaleEffect(2)
                    .padding()
                Text("Generating Sleep Score..")
            } else {
                // Score display circle
                ZStack {
                    Circle()
                        .stroke(
                            Color.blue.opacity(0.2),
                            lineWidth: 15
                        )
                    
                    Circle()
                        .trim(from: 0, to: CGFloat(sleepScore) / 100)
                        .stroke(
                            scoreColor(),
                            style: StrokeStyle(
                                lineWidth: 15,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(-90))
                    
                    VStack {
                        Text("\(sleepScore)")
                            .font(.system(size: 80, weight: .bold))
                        Text("Sleep Score")
                            .font(.headline)
                    }
                }
                .frame(width: 250, height: 250)
                .padding()
                
                Button("Generate New Score") {
                    generateScore()
                }
                .padding()
                .background(Color.blue)
                .foregroundColor(.white)
                .cornerRadius(10)
                .padding(.top, 30)
            }
        }
        .padding()
        .onAppear {
            generateScore()
        }
    }
    
    func scoreColor() -> Color {
        if sleepScore >= 80 {
            return Color.green
        } else if sleepScore >= 60 {
            return Color.yellow
        } else {
            return Color.red
        }
    }
    
    func generateScore() {
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Simulate some processing time
            Thread.sleep(forTimeInterval: 0.5)
            
            // Generate random sleep score (equivalent to Python's random.randint(1, 100))
            let newScore = Int.random(in: 1...100)
            
            DispatchQueue.main.async {
                self.sleepScore = newScore
                self.isLoading = false
            }
        }
    }
}
