import SwiftUI

@main
struct DisplayInputSwitchApp: App {
  @StateObject private var store = Store()
  @AppStorage("menuIcon") private var icon = MenuIcon.fallback

  var body: some Scene {
    MenuBarExtra {
      MenuContent().environmentObject(store)
    } label: {
      Image(systemName: MenuIcon.exists(icon) ? icon : MenuIcon.fallback)
    }

    Window("DisplayInputSwitch 설정", id: "settings") {
      SettingsView().environmentObject(store)
    }
    .windowResizability(.contentSize)
    .defaultLaunchBehavior(.suppressed)   // 켤 때 설정창은 안 띄움
  }
}

struct MenuContent: View {
  @EnvironmentObject private var store: Store
  @Environment(\.openWindow) private var openWindow

  var body: some View {
    if store.monitors.isEmpty {
      Text(store.loading ? "모니터 찾는 중…" : "바깥 모니터 없음")
    }
    ForEach(store.monitors) { m in
      Section(m.name) {
        if m.responds {
          ForEach(store.inputs.filter(\.enabled)) { slot in
            Toggle(slot.name, isOn: Binding(
              get: { m.current == slot.code },
              set: { _ in store.switchInput(m, to: slot.code) }
            ))
          }
          if let c = m.current, store.name(of: c) == nil {
            Text("지금 입력: 번호 \(c) (목록에 없음)")
          }
        } else {
          Text("DDC 응답 없음 — 전환할 수 없음")
        }
      }
    }
    Divider()
    Button("새로고침") { store.refresh() }
    Button("설정…") {
      NSApp.activate()
      openWindow(id: "settings")
    }
    .keyboardShortcut(",")
    Divider()
    Button("끝내기") { NSApp.terminate(nil) }
      .keyboardShortcut("q")
  }
}
