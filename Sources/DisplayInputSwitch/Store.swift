import AppKit
import SwiftUI

/// 입력 하나(이름은 사용자가 붙임, 번호는 모니터에 보내는 VCP 0x60 값)
struct InputSlot: Codable, Identifiable, Hashable {
  var id = UUID()
  var name: String
  var code: Int
  var enabled = true

  /// MCCS 표준 번호. 모니터마다 다를 수 있음(예: 필립스 32M2N8900 USB-C = 15)
  static let defaults: [InputSlot] = [
    .init(name: "DisplayPort 1", code: 15),
    .init(name: "DisplayPort 2", code: 16),
    .init(name: "HDMI 1", code: 17),
    .init(name: "HDMI 2", code: 18),
    .init(name: "USB-C", code: 27),
  ]
}

/// 메뉴에 보여 줄 모니터 상태
struct MonitorItem: Identifiable {
  let id: Int            // 순번(연결 순서)
  let name: String
  let ddc: DDCMonitor
  var current: Int?      // 지금 입력 번호, 못 읽으면 nil
  var responds: Bool     // DDC 응답이 한 번이라도 있었는지
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
  @Published var inputs: [InputSlot] {
    didSet { if let d = try? JSONEncoder().encode(inputs) { UserDefaults.standard.set(d, forKey: "inputs") } }
  }

  private var lastRefresh = Date.distantPast
  private var menuObserver: NSObjectProtocol?

  init() {
    if let d = UserDefaults.standard.data(forKey: "inputs"), let v = try? JSONDecoder().decode([InputSlot].self, from: d) {
      inputs = v
    } else {
      inputs = InputSlot.defaults
    }
    refresh()
    // 메뉴를 열 때마다 지금 입력을 다시 읽음(너무 잦으면 건너뜀)
    menuObserver = NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification, object: nil, queue: .main) { [weak self] _ in
      MainActor.assumeIsolated {
        guard let self, Date().timeIntervalSince(self.lastRefresh) > 3 else { return }
        self.refresh()
      }
    }
  }

  func name(of code: Int) -> String? { inputs.first { $0.code == code }?.name }

  /// 모니터 목록과 지금 입력을 다시 읽음(메인 스레드 밖에서)
  func refresh() {
    lastRefresh = Date()
    let known = Dictionary(uniqueKeysWithValues: monitors.map { ($0.name + "#\($0.id)", $0) })
    Task.detached {
      let found = DDCMonitor.all().enumerated().map { i, m in
        let cur = m.read(VCP.input)?.current
        return (i, m, cur)
      }
      await MainActor.run {
        self.monitors = found.map { i, m, cur in
          // 입력을 바꾸는 중엔 잠깐 못 읽으니 전에 읽은 값을 유지
          let old = known[m.name + "#\(i)"]
          return MonitorItem(id: i, name: m.name, ddc: m, current: cur ?? old?.current, responds: cur != nil || (old?.responds ?? false))
        }
        self.loading = false
      }
    }
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
