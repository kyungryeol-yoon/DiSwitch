import SwiftUI

@main
struct DiSwitchApp: App {
  @StateObject private var store = Store()
  @AppStorage("menuIcon") private var icon = MenuIcon.fallback

  init() {
    LegacyDefaults.migrate()   // 옛 번들 ID의 설정을 옮김 — Store·@AppStorage가 읽기 전에
  }

  var body: some Scene {
    MenuBarExtra {
      MenuContent().environmentObject(store)
    } label: {
      Image(systemName: MenuIcon.exists(icon) ? icon : MenuIcon.fallback)
    }

    Window("DiSwitch 설정", id: "settings") {
      SettingsView().environmentObject(store)
    }
    .windowResizability(.contentSize)
    .defaultLaunchBehavior(.suppressed)   // 켤 때 설정창은 안 띄움
  }
}

struct MenuContent: View {
  @EnvironmentObject private var store: Store
  @Environment(\.openWindow) private var openWindow
  @AppStorage("thisMacMark") private var mark = ThisMacMark.fallback

  var body: some View {
    if store.monitors.isEmpty {
      Text(store.loading ? "모니터 찾는 중…" : "바깥 모니터 없음")
    }
    ForEach(store.monitors) { m in
      Section(m.name) {
        if !m.responds {
          Text(m.checked ? "DDC 응답 없음 — 전환할 수 없음" : "확인 중…")
        } else if store.config(m) == nil {
          Text("입력 번호를 모니터에서 읽는 중…")
        } else {
          let thisMac = store.config(m)?.thisMac
          ForEach(store.visibleInputs(m)) { slot in
            Toggle(slot.displayName + (slot.code == thisMac ? "  " + mark : ""), isOn: Binding(
              get: { m.current == slot.code },
              set: { _ in store.switchInput(m, to: slot.code) }
            ))
          }
          if let c = m.current, !store.visibleInputs(m).contains(where: { $0.code == c }) {
            Text("지금 입력: \(store.slot(m, code: c)?.displayName ?? "입력 \(c)") (메뉴에 숨김)")
          }
        }
      }
    }
    Divider()
    // 자주 켜고 끄는 거라 설정창 대신 메뉴에 둠. 이 맥 입력(표시)을 알아야 동작
    // 체크는 「자동으로 깨워 두기」를 켠 것. 실제로 막는지는 밑 줄에 따로 보여 줌(체크와 헷갈리지 않게)
    Toggle("다른 기기 볼 때 이 맥 깨워 두기", isOn: $store.keepAwake)
    if store.keepAwake {
      if store.keepingAwake {
        Text("깨워 두는 중")
      } else if !store.monitors.contains(where: { store.config($0)?.thisMac != nil }) {
        Text("이 맥 입력을 몰라요 — 이 맥 화면에서 메뉴를 열어 주세요")
      } else {
        Text("대기 중 — 이 맥을 보고 있어요")
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
