import CryptoKit
import Foundation
import Security

protocol ClipboardHistoryPersisting {
  func load() throws -> [ClipboardEntry]
  func save(_ entries: [ClipboardEntry]) throws
}

struct EncryptedClipboardHistoryStore: ClipboardHistoryPersisting {
  private static let keychainAccount = "clipboard-history"
  private static let keychainService = "dev.tombell.conjuror"

  private let fileURL: URL
  private let keyProvider: () throws -> SymmetricKey

  init(
    fileURL: URL = Self.defaultFileURL,
    keyProvider: @escaping () throws -> SymmetricKey = Self.loadOrCreateKey
  ) {
    self.fileURL = fileURL
    self.keyProvider = keyProvider
  }

  func load() throws -> [ClipboardEntry] {
    guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
    let sealedData = try Data(contentsOf: fileURL)
    let sealedBox = try AES.GCM.SealedBox(combined: sealedData)
    let clearData = try AES.GCM.open(sealedBox, using: keyProvider())
    return try JSONDecoder().decode([ClipboardEntry].self, from: clearData)
  }

  func save(_ entries: [ClipboardEntry]) throws {
    let clearData = try JSONEncoder().encode(entries)
    let sealedBox = try AES.GCM.seal(clearData, using: keyProvider())
    guard let combined = sealedBox.combined else {
      throw ClipboardHistoryStoreError.couldNotEncodeEncryptedData
    }
    try FileManager.default.createDirectory(
      at: fileURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try combined.write(to: fileURL, options: [.atomic, .completeFileProtection])
  }

  private static var defaultFileURL: URL {
    let applicationSupport =
      FileManager.default.urls(
        for: .applicationSupportDirectory,
        in: .userDomainMask
      ).first ?? FileManager.default.temporaryDirectory
    return
      applicationSupport
      .appending(path: "Conjuror", directoryHint: .isDirectory)
      .appending(path: "ClipboardHistory.data")
  }

  private static func loadOrCreateKey() throws -> SymmetricKey {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    if status == errSecSuccess, let data = result as? Data {
      return SymmetricKey(data: data)
    }
    guard status == errSecItemNotFound else {
      throw ClipboardHistoryStoreError.keychain(status)
    }

    let key = SymmetricKey(size: .bits256)
    let data = key.withUnsafeBytes { Data($0) }
    let addQuery: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: keychainService,
      kSecAttrAccount as String: keychainAccount,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
      kSecValueData as String: data,
    ]
    let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
    guard addStatus == errSecSuccess else {
      throw ClipboardHistoryStoreError.keychain(addStatus)
    }
    return key
  }
}

enum ClipboardHistoryStoreError: Error {
  case couldNotEncodeEncryptedData
  case keychain(OSStatus)
}
