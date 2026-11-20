import Foundation

/// 번들 ID를 `app.displayinputswitch` → `io.github.kyungryeol-yoon.diswitch`로 바꿈(2026-11-21).
/// UserDefaults는 번들 ID별 파일(~/Library/Preferences/<ID>.plist)이라 그냥 두면 설정이 전부 사라진다.
/// 그래서 처음 켤 때 한 번, 옛 파일의 값을 새 파일로 옮기고 옛 것은 지운다.
/// 설정을 읽는 곳(@AppStorage, Store)보다 먼저 불려야 한다 → `DiSwitchApp.init()`.
enum LegacyDefaults {
  static let oldDomain = "app.displayinputswitch"

  /// 옛 값이 없으면 아무것도 안 함. 새 쪽에 이미 있는 키는 덮어쓰지 않음(새 버전에서 바꾼 값이 이김).
  static func migrate(from old: String = oldDomain, to defaults: UserDefaults = .standard) {
    guard let values = defaults.persistentDomain(forName: old), !values.isEmpty else { return }
    for (key, value) in values where defaults.object(forKey: key) == nil {
      defaults.set(value, forKey: key)
    }
    defaults.removePersistentDomain(forName: old)
  }
}
