import UIKit
import HealthKit

class AppDelegate: NSObject, UIApplicationDelegate {
    var healthStore: HKHealthStore?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        // Initialize HealthKit if available
        if HKHealthStore.isHealthDataAvailable() {
            healthStore = HKHealthStore()
            print("HealthKit is available on this device")
        } else {
            print("HealthKit is not available on this device")
        }
        
        print("NightScore app launched successfully")
        return true
    }
    
    // Handle background refresh if needed
    func application(_ application: UIApplication, performFetchWithCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        // In a more advanced version, this could automatically update sleep scores
        // during background refresh
        completionHandler(.noData)
    }
}