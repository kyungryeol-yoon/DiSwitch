import AppKit
import SwiftUI

/// 입력 하나(번호는 모니터에 보내는 VCP 0x60 값, 이름은 사용자가 붙인 별칭 — 비어 있으면 「입력 N」)
struct InputSlot: Codable, Identifiable, Hashable {
  var id = UUID()
  var name = ""
  var code: Int
  var enabled = true

  var displayName: String { name.isEmpty ? "입력 \(code)" : name }

  /// MCCS 표준표의 이름. 모니터마다 다를 수 있어서(필립스 32M2N8900은 15번이 USB-C) 참고로만 보여 줌
  static func standardName(_ code: Int) -> String? {
    switch code {
    case 0x01: "VGA 1"
    case 0x02: "VGA 2"
    case 0x03: "DVI 1"
    case 0x04: "DVI 2"
    case 0x0F: "DisplayPort 1"
    case 0x10: "DisplayPort 2"
    case 0x11: "HDMI 1"
    case 0x12: "HDMI 2"
    case 0x1B: "USB-C"
    default: nil
    }
  }

  /// 모니터가 기능 목록을 안 알려 줄 때 쓰는 흔한 번호
  static let fallbackCodes = [0x0F, 0x10, 0x11, 0x12, 0x1B]
}

/// 모니터 한 대의 설정(저장됨)
struct MonitorConfig: Codable {
  var name: String
  var inputs: [InputSlot]
  /// 이 맥이 연결된 입력 번호(이 맥에서 메뉴를 열었을 때 모니터가 보여 주던 입력)
  var thisMac: Int?
  /// 입력 목록을 모니터의 기능 목록에서 가져왔는지(false면 흔한 번호로 짐작한 것)
  var fromMonitor: Bool

  /// 모니터가 알려 준 번호로 목록을 만듦. 표준표에 있는 번호만 보이게 하고 나머지는 숨김
  static func make(name: String, codes: [Int]?) -> MonitorConfig {
    let list = Array(Set(codes ?? InputSlot.fallbackCodes)).sorted()
    return MonitorConfig(
      name: name,
      inputs: list.map { InputSlot(code: $0, enabled: InputSlot.standardName($0) != nil) },
      thisMac: nil,
      fromMonitor: codes != nil)
  }
}

/// 메뉴에 보여 줄 모니터 상태
struct MonitorItem: Identifiable {
  var id: String { key }
  let key: String        // MonitorConfig를 찾는 열쇠
  let name: String
  let ddc: DDCMonitor
  var current: Int?      // 지금 입력 번호, 못 읽으면 nil
  var responds: Bool     // DDC 응답이 한 번이라도 있었는지
  var checked: Bool      // 한 번이라도 읽어 봤는지(응답 없는 모니터는 확인에 20초 넘게 걸리기도 함)
}

/// 메뉴에서 이 맥 입력 옆에 붙는 표시
enum ThisMacMark {
  static let fallback = "◀\u{FE0E}"
  static let candidates = ["◀\u{FE0E}", "★", "⭐️", "📍", "👈", "🖥️", "💻", "🏠", "🟢", "🔵", "💡", "🎯"]
}

enum MenuIcon {
  static let fallback = "display.2"
  /// 설정창에 보여 줄 후보(rectangle.on.rectangle은 macOS 화면 미러링과 같아서 뺌)
  static let candidates = [
    "display.2", "display", "display.and.arrow.down", "rectangle.2.swap",
    "arrow.left.arrow.right.square", "arrow.left.arrow.right.circle", "arrow.triangle.2.circlepath", "arrow.triangle.swap",
    "rectangle.connected.to.line.below", "cable.connector", "cable.connector.horizontal", "switch.2",
    "square.on.square", "rectangle.on.rectangle.angled", "rectangle.split.2x1", "tv",
    "inset.filled.tv", "laptopcomputer.and.arrow.down", "macmini", "gamecontroller",
  ]
  static func exists(_ name: String) -> Bool {
    !name.isEmpty && NSImage(systemSymbolName: name, accessibilityDescription: nil) != nil
  }
}

@MainActor
final class Store: ObservableObject {
  @Published var monitors: [MonitorItem] = []
  @Published var loading = true
  @Published var configs: [String: MonitorConfig] {
    didSet { if let d = try? JSONEncoder().encode(configs) { UserDefaults.standard.set(d, forKey: "monitors") } }
  }
  /// 기능 목록을 읽는 중인 모니터(처음 한 번, 몇 초 걸림)
  @Published var scanning: Set<String> = []

  private var lastRefresh = Date.distantPast
  private var observers: [NSObjectProtocol] = []
  private var pendingRefresh: Task<Void, Never>?

  init() {
    if let d = UserDefaults.standard.data(forKey: "monitors"), let v = try? JSONDecoder().decode([String: MonitorConfig].self, from: d) {
      configs = v
    } else {
      configs = [:]
    }
    refresh()
    // 메뉴를 열 때마다 지금 입력을 다시 읽음.
    // 마우스가 있는 화면의 모니터 = 사용자가 지금 보고 있는 화면 = 이 맥을 보여 주는 중 → 그 모니터의 지금 입력을 이 맥 입력으로 기억
    // (다른 모니터에서 메뉴를 열면 기억하지 않음 — 그 모니터는 다른 기기를 보여 주는 중일 수 있음)
    observers.append(NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, Date().timeIntervalSince(self.lastRefresh) > 3 else { return }
        self.refresh(menuOpenedOn: Self.displayUnderMouse(), fromMenu: true)
      }
    })
    // 모니터를 꽂거나 뺐을 때·화면 배치가 바뀌었을 때, 잠자기에서 깨어났을 때 다시 읽음
    // (깨어난 직후엔 모니터 연결이 아직 안 잡혔을 수 있어 조금 기다림. 알림이 여러 번 와도 한 번만)
    observers.append(NotificationCenter.default.addObserver(forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshSoon(after: 2) }
    })
    observers.append(NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated { self?.refreshSoon(after: 3) }
    })
  }

  private func refreshSoon(after seconds: Double) {
    pendingRefresh?.cancel()
    pendingRefresh = Task { [weak self] in
      try? await Task.sleep(for: .seconds(seconds))
      guard !Task.isCancelled else { return }
      self?.refresh()
    }
  }

  /// 마우스가 있는 화면의 id
  private static func displayUnderMouse() -> CGDirectDisplayID? {
    let p = NSEvent.mouseLocation
    let screen = NSScreen.screens.first { NSMouseInRect(p, $0.frame, false) }
    return screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
  }

  func config(_ m: MonitorItem) -> MonitorConfig? { configs[m.key] }

  /// 메뉴에 보일 입력들
  func visibleInputs(_ m: MonitorItem) -> [InputSlot] { config(m)?.inputs.filter(\.enabled) ?? [] }

  func slot(_ m: MonitorItem, code: Int) -> InputSlot? { config(m)?.inputs.first { $0.code == code } }

  /// 모니터 목록과 지금 입력을 다시 읽음(메인 스레드 밖에서)
  /// menuOpenedOn: 메뉴를 연 화면 — 그 모니터의 지금 입력을 이 맥 입력으로 기억. 메뉴를 열 땐 응답 없던 모니터는 다시 읽지 않음
  /// (응답 없는 모니터는 확인하는 데 20초 넘게 걸리기도 함. 「새로고침」은 전부 다시 읽음)
  func refresh(menuOpenedOn display: CGDirectDisplayID? = nil, fromMenu: Bool = false) {
    lastRefresh = Date()
    let old = Dictionary(monitors.map { ($0.key, $0) }, uniquingKeysWith: { a, _ in a })
    let skip = fromMenu ? Set(monitors.filter { $0.checked && !$0.responds }.map(\.key)) : []
    Task.detached {
      let all = DDCMonitor.all().enumerated().map { i, m in (key: m.key.isEmpty ? "\(m.name)#\(i)" : m.key, ddc: m) }
      await MainActor.run {
        // 목록은 바로 보여 주고, 입력은 모니터마다 따로 읽어서 나오는 대로 채움(느린 모니터가 다른 모니터를 막지 않게)
        self.monitors = all.map { m in
          let o = old[m.key]
          return MonitorItem(key: m.key, name: m.ddc.name, ddc: m.ddc, current: o?.current,
                             responds: o?.responds ?? false, checked: o?.checked ?? false)
        }
        self.loading = false
      }
      for m in all where !skip.contains(m.key) {
        Task.detached {
          let cur = m.ddc.read(VCP.input)?.current
          let mine = display.map { m.ddc.matches($0) } ?? false
          await MainActor.run { self.update(key: m.key, ddc: m.ddc, current: cur, rememberThisMac: mine) }
        }
      }
    }
  }

  private func update(key: String, ddc: DDCMonitor, current: Int?, rememberThisMac: Bool) {
    guard let i = monitors.firstIndex(where: { $0.key == key }) else { return }
    // 입력을 바꾸는 중엔 잠깐 못 읽으니 전에 읽은 값을 유지
    if let current { monitors[i].current = current; monitors[i].responds = true }
    monitors[i].checked = true
    guard let current else { return }
    if configs[key] == nil { scanInputs(key: key, ddc: ddc) }
    if rememberThisMac, configs[key] != nil, configs[key]?.thisMac != current { configs[key]?.thisMac = current }
  }

  /// 모니터에게 입력 번호 목록을 물어서 입력 목록을 (다시) 만듦. 이미 붙인 별칭은 번호가 같으면 유지
  func scanInputs(key: String, ddc: DDCMonitor) {
    guard !scanning.contains(key) else { return }
    scanning.insert(key)
    Task.detached {
      let codes = ddc.capabilities().flatMap(DDCMonitor.inputCodes)
      await MainActor.run {
        var new = MonitorConfig.make(name: ddc.name, codes: codes)
        // 이미 붙인 별칭과 보임 여부는 유지(0.1의 모니터 공통 목록 "inputs"도 처음 한 번 옮겨 옴)
        let prev = self.configs[key]?.inputs ?? Self.takeLegacyInputs()
        new.thisMac = self.configs[key]?.thisMac
        new.inputs = new.inputs.map { s in prev.first { $0.code == s.code } ?? s }
        self.configs[key] = new
        self.scanning.remove(key)
      }
    }
  }

  /// 0.1에서 쓰던 모니터 공통 입력 목록을 꺼내고 지움(한 번만)
  private static func takeLegacyInputs() -> [InputSlot] {
    struct Old: Codable { var name: String; var code: Int; var enabled: Bool }
    guard let d = UserDefaults.standard.data(forKey: "inputs") else { return [] }
    UserDefaults.standard.removeObject(forKey: "inputs")
    let old = (try? JSONDecoder().decode([Old].self, from: d)) ?? []
    // 표준 이름 그대로였던 건 별칭이 아니므로 비움
    return old.map { InputSlot(name: InputSlot.standardName($0.code) == $0.name ? "" : $0.name, code: $0.code, enabled: $0.enabled) }
  }

  func switchInput(_ monitor: MonitorItem, to code: Int) {
    if let i = monitors.firstIndex(where: { $0.id == monitor.id }) { monitors[i].current = code }
    let ddc = monitor.ddc
    Task.detached {
      ddc.write(VCP.input, code)
      try? await Task.sleep(for: .seconds(4))   // 모니터가 새 입력을 잡는 동안은 읽기 응답이 없음
      await MainActor.run { self.refresh() }
    }
  }
}
