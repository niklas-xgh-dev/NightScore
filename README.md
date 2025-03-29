# NightScore

NightScore is an iOS application that calculates and displays a sleep quality score based on your Apple Health sleep data.

## Features

- Securely accesses sleep data from Apple Health
- Calculates a sleep quality score (0-100) based on multiple factors:
  - Total sleep duration
  - Deep sleep percentage
  - Sleep efficiency
  - Resting heart rate (when available)
- Fully local processing - your sleep data never leaves your device
- Simple, intuitive interface with detailed sleep metrics

## Requirements

- iOS 14.0+
- Xcode 12.0+
- iPhone with Apple Health app containing sleep data

## Installation

1. Clone the repository to your local machine
2. Open the NightScore.xcodeproj file in Xcode
3. Configure your development team in the project settings
4. Build and run the app on your device or simulator

## Testing on a Physical Device

1. Connect your iPhone to your Mac
2. Select your device in the Xcode device dropdown
3. Build and run the app
4. When prompted, authorize NightScore to access your Health data
5. The app will analyze your most recent night's sleep and display your score

## Testing on Simulator

When testing on the iOS Simulator, no real Health data will be available. The app will display appropriate messages when no data is found.

To test HealthKit functionality fully, you must use a physical device with Health data.

## Troubleshooting

- **No Sleep Data**: Ensure you have sleep data recorded in the Apple Health app
- **Authorization Issues**: Open the Health app on your device, go to "Data Access & Devices" and verify that NightScore has the necessary permissions
- **Incorrect Scores**: The current algorithm is a simple MVP. Future versions will include more sophisticated analysis

## Privacy

NightScore is designed with privacy in mind:
- All data processing happens locally on your device
- No data is ever uploaded to any server
- No analytics or tracking code is included

## Next Steps

Future versions of NightScore may include:
- Trend analysis of sleep patterns over time
- More detailed sleep stage visualizations
- Custom recommendations for improving sleep quality
- Apple Watch app for viewing your score