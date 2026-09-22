import Foundation

func makeTestUserDefaults(
  fileID: String = #fileID,
  function: String = #function
) -> UserDefaults {
  let suiteName = "ConjurorTests.\(fileID).\(function).\(UUID().uuidString)"
  let userDefaults = UserDefaults(suiteName: suiteName)!
  userDefaults.removePersistentDomain(forName: suiteName)

  return userDefaults
}
