import AppKit
import Foundation

struct SystemSettingsCatalog {
  static let items: [InstalledApplication] = {
    let settingsURL = URL(fileURLWithPath: "/System/Applications/System Settings.app")
    let icon = NSWorkspace.shared.icon(forFile: settingsURL.path)
    return sections.compactMap { name, identifier in
      guard let url = URL(string: "x-apple.systempreferences:\(identifier)") else { return nil }
      return InstalledApplication(
        displayName: name,
        bundleIdentifier: nil,
        url: settingsURL,
        icon: icon,
        launchTarget: .systemSettings(url)
      )
    }
  }()

  private static let sections = [
    ("About", "com.apple.SystemProfiler.AboutExtension"),
    ("Accessibility", "com.apple.Accessibility-Settings.extension"),
    ("AirDrop & Handoff", "com.apple.AirDrop-Handoff-Settings.extension"),
    ("Appearance", "com.apple.Appearance-Settings.extension"),
    ("Apple Account", "com.apple.systempreferences.AppleIDSettings"),
    ("Apple Intelligence & Siri", "com.apple.Siri-Settings.extension"),
    ("Battery", "com.apple.Battery-Settings.extension"),
    ("Bluetooth", "com.apple.BluetoothSettings"),
    ("Date & Time", "com.apple.Date-Time-Settings.extension"),
    ("Desktop & Dock", "com.apple.Desktop-Settings.extension"),
    ("Displays", "com.apple.Displays-Settings.extension"),
    ("Family", "com.apple.Family-Settings.extension"),
    ("Focus", "com.apple.Focus-Settings.extension"),
    ("Game Center", "com.apple.Game-Center-Settings.extension"),
    ("Game Controllers", "com.apple.Game-Controller-Settings.extension"),
    ("General", "com.apple.systempreferences.GeneralSettings"),
    ("Internet Accounts", "com.apple.Internet-Accounts-Settings.extension"),
    ("Keyboard", "com.apple.Keyboard-Settings.extension"),
    ("Language & Region", "com.apple.Localization-Settings.extension"),
    ("Lock Screen", "com.apple.Lock-Screen-Settings.extension"),
    ("Login Items & Extensions", "com.apple.LoginItems-Settings.extension"),
    ("Menu Bar", "com.apple.ControlCenter-Settings.extension"),
    ("Mouse", "com.apple.Mouse-Settings.extension"),
    ("Network", "com.apple.Network-Settings.extension"),
    ("Notifications", "com.apple.Notifications-Settings.extension"),
    ("Printers & Scanners", "com.apple.Print-Scan-Settings.extension"),
    ("Privacy & Security", "com.apple.settings.PrivacySecurity.extension"),
    ("Screen Saver", "com.apple.ScreenSaver-Settings.extension"),
    ("Screen Time", "com.apple.Screen-Time-Settings.extension"),
    ("Sharing", "com.apple.Sharing-Settings.extension"),
    ("Software Update", "com.apple.Software-Update-Settings.extension"),
    ("Sound", "com.apple.Sound-Settings.extension"),
    ("Spotlight", "com.apple.Spotlight-Settings.extension"),
    ("Storage", "com.apple.settings.Storage"),
    ("Time Machine", "com.apple.Time-Machine-Settings.extension"),
    ("Touch ID & Password", "com.apple.Touch-ID-Settings.extension"),
    ("Trackpad", "com.apple.Trackpad-Settings.extension"),
    ("Transfer or Reset", "com.apple.Transfer-Reset-Settings.extension"),
    ("Users & Groups", "com.apple.Users-Groups-Settings.extension"),
    ("Wallet & Apple Pay", "com.apple.WalletSettingsExtension"),
    ("Wallpaper", "com.apple.Wallpaper-Settings.extension"),
    ("Wi-Fi", "com.apple.wifi-settings-extension"),
  ]
}
