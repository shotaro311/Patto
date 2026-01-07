import Foundation

enum QuickMemoControlStore {
  static let appGroupId = "group.com.patto.patto"
  static let requestKey = "quickMemoOpenRequested"

  static func requestOpen() {
    guard let defaults = UserDefaults(suiteName: appGroupId) else { return }
    defaults.set(true, forKey: requestKey)
  }

  static func consumeRequest() -> Bool {
    guard let defaults = UserDefaults(suiteName: appGroupId) else { return false }
    let requested = defaults.bool(forKey: requestKey)
    if requested {
      defaults.set(false, forKey: requestKey)
    }
    return requested
  }
}
