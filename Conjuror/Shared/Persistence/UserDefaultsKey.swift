import Foundation

struct UserDefaultsKey<Value> {
  let name: String

  init(_ name: String) {
    self.name = name
  }
}

extension UserDefaults {
  func value<Value>(for key: UserDefaultsKey<Value>) -> Value? {
    object(forKey: key.name) as? Value
  }

  func set<Value>(_ value: Value?, for key: UserDefaultsKey<Value>) {
    set(value, forKey: key.name)
  }
}
