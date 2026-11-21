import ServiceManagement
import SwiftUI

struct SettingsView: View {
  var body: some View {
    TabView {
      GeneralSettings().tabItem { Label("일반", systemImage: "gearshape") }
      IconSettings().tabItem { Label("아이콘", systemImage: "paintbrush") }
      InputSettings().tabItem { Label("입력", systemImage: "list.bullet") }
    }
    .frame(width: 520, height: 460)
  }
}

// MARK: - 일반

struct GeneralSettings: View {
  @EnvironmentObject private var store: Store
  @AppStorage("thisMacMark") private var mark = ThisMacMark.fallback
  @State private var launchAtLogin = false
  @State private var needsApproval = false
  @State private var error: String?
  @State private var custom = ""

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      // 사용자가 눌렀을 때만 등록·해제(상태를 다시 읽어 넣을 때 또 불리지 않게 onChange 대신 Binding의 set에서)
      Toggle("로그인할 때 자동으로 실행", isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) }))
      if needsApproval {
        HStack(spacing: 8) {
          Text("「로그인 항목」에서 DiSwitch를 허용해야 켜져요.").font(.caption).foregroundStyle(.orange)
          Button("로그인 항목 열기") { SMAppService.openSystemSettingsLoginItems() }.controlSize(.small)
        }
      }
      Text("「시스템 설정 → 일반 → 로그인 항목」에서도 끄고 켤 수 있어요.")
        .font(.caption).foregroundStyle(.secondary)
      if let error { Text(error).foregroundStyle(.red).font(.caption) }

      Divider().padding(.vertical, 8)

      Text("현재 디스플레이 표시").font(.headline)
      Text("메뉴에서 지금 쓰고 있는 이 맥이 연결된 입력 옆에 붙어요.").foregroundStyle(.secondary)
      HStack(alignment: .top, spacing: 20) {
        VStack(alignment: .leading, spacing: 10) {
          LazyVGrid(columns: Array(repeating: GridItem(.fixed(40), spacing: 8), count: 6), alignment: .leading, spacing: 8) {
            ForEach(ThisMacMark.candidates, id: \.self) { m in
              Button { mark = m } label: {
                Text(m).font(.system(size: 17))
                  .frame(width: 40, height: 34)
                  .background(RoundedRectangle(cornerRadius: 7).fill(mark == m ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.08)))
                  .overlay(RoundedRectangle(cornerRadius: 7).stroke(mark == m ? Color.accentColor : .clear, lineWidth: 2))
                  .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
            }
          }
          HStack {
            TextField("직접 입력(이모지·글자)", text: $custom)
              .textFieldStyle(.roundedBorder).frame(width: 170)
              .onSubmit(applyCustom)
            Button("적용", action: applyCustom).disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
          }
          Text("이모지는 ⌃⌘Space로 넣을 수 있어요.").font(.caption).foregroundStyle(.secondary)
        }
        MenuPreview(mark: mark, names: previewNames)
      }
      Spacer()
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear(perform: readLaunchAtLogin)
  }

  /// 미리보기용 입력 이름(연결된 모니터의 실제 별칭, 없으면 예시)
  private var previewNames: (mine: String, others: [String]) {
    if let m = store.monitors.first(where: { store.config($0)?.thisMac != nil }), let c = store.config(m), let t = c.thisMac {
      let vis = c.inputs.filter(\.enabled)
      return (c.inputs.first { $0.code == t }?.displayName ?? "입력 \(t)", vis.filter { $0.code != t }.map(\.displayName).prefix(2).map { $0 })
    }
    return ("Mac mini", ["MacBook Pro", "Game console"])
  }

  private func applyCustom() {
    let v = String(custom.trimmingCharacters(in: .whitespaces).prefix(4))
    if !v.isEmpty { mark = v; custom = "" }
  }

  private func setLaunchAtLogin(_ on: Bool) {
    do {
      if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
      error = nil
    } catch {
      self.error = "바꾸지 못함: \(error.localizedDescription)"
    }
    readLaunchAtLogin()
  }

  /// 실제 상태를 스위치에 반영(등록·해제는 안 함). 허용 대기(.requiresApproval)도 등록은 된 것이라 켜짐으로 보여 줌
  private func readLaunchAtLogin() {
    let status = SMAppService.mainApp.status
    launchAtLogin = status == .enabled || status == .requiresApproval
    needsApproval = status == .requiresApproval
  }
}

/// 메뉴처럼 보이는 작은 미리보기
struct MenuPreview: View {
  let mark: String
  let names: (mine: String, others: [String])

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("미리보기").font(.caption).foregroundStyle(.secondary)
      VStack(alignment: .leading, spacing: 5) {
        HStack(spacing: 6) { Text("✓").frame(width: 12); Text(names.mine + "  " + mark) }
        ForEach(names.others, id: \.self) { n in HStack(spacing: 6) { Text("").frame(width: 12); Text(n) } }
      }
      .font(.system(size: 13))
      .padding(10)
      .frame(minWidth: 200, alignment: .leading)
      .background(RoundedRectangle(cornerRadius: 8).fill(.background))
      .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.secondary.opacity(0.3)))
    }
  }
}

// MARK: - 아이콘

struct IconSettings: View {
  @AppStorage("menuIcon") private var icon = MenuIcon.fallback
  @State private var custom = ""

  private let columns = Array(repeating: GridItem(.fixed(52), spacing: 10), count: 7)

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(spacing: 12) {
        Text("메뉴 막대에서 보기").font(.headline)
        MenuBarPreview(symbol: icon, dark: false)
        MenuBarPreview(symbol: icon, dark: true)
        Spacer()
      }
      Text("누르면 메뉴 막대 아이콘이 바로 바뀌어요.").foregroundStyle(.secondary)

      LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
        ForEach(MenuIcon.candidates, id: \.self) { name in
          Button { icon = name } label: {
            Image(systemName: name)
              .font(.system(size: 18))
              .frame(width: 52, height: 44)
              .background(RoundedRectangle(cornerRadius: 8).fill(icon == name ? Color.accentColor.opacity(0.25) : Color.secondary.opacity(0.08)))
              .overlay(RoundedRectangle(cornerRadius: 8).stroke(icon == name ? Color.accentColor : .clear, lineWidth: 2))
              .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
          .help(name)
        }
      }

      Divider()

      VStack(alignment: .leading, spacing: 6) {
        Text("SF Symbols 이름으로 직접 넣기").font(.headline)
        HStack {
          TextField("예: display.2", text: $custom)
            .textFieldStyle(.roundedBorder)
            .frame(width: 240)
            .onSubmit(applyCustom)
          if MenuIcon.exists(custom) {
            Image(systemName: custom).font(.system(size: 16)).frame(width: 24)
            Button("적용", action: applyCustom)
          } else if !custom.isEmpty {
            Text("그런 이름 없음").foregroundStyle(.red)
          }
        }
        Text("지금: \(icon)").font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
      }
      Spacer()
    }
    .padding(20)
  }

  private func applyCustom() {
    let n = custom.trimmingCharacters(in: .whitespaces)
    if MenuIcon.exists(n) { icon = n }
  }
}

/// 메뉴 막대처럼 보이는 작은 띠(밝은/어두운)
struct MenuBarPreview: View {
  let symbol: String
  let dark: Bool

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: "wifi")
      Image(systemName: MenuIcon.exists(symbol) ? symbol : MenuIcon.fallback)
      Image(systemName: "magnifyingglass")
    }
    .font(.system(size: 13))
    .foregroundStyle(dark ? .white : .black)
    .padding(.horizontal, 12)
    .frame(height: 24)
    .background(RoundedRectangle(cornerRadius: 6).fill(dark ? Color(white: 0.15) : Color(white: 0.93)))
    .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.3)))
  }
}

// MARK: - 입력

struct InputSettings: View {
  @EnvironmentObject private var store: Store
  @State private var selected: String?

  /// 지금 연결된 모니터 먼저, 그다음 예전에 본 모니터
  private var keys: [String] {
    let connected = store.monitors.map(\.key).filter { store.configs[$0] != nil }
    return connected + store.configs.keys.filter { !connected.contains($0) }.sorted()
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if keys.isEmpty {
        Text(store.scanning.isEmpty ? "DDC로 제어할 수 있는 모니터가 없어요." : "모니터에서 입력 번호를 읽는 중…")
          .foregroundStyle(.secondary)
        Spacer()
      } else {
        let key = selected.flatMap { keys.contains($0) ? $0 : nil } ?? keys[0]
        if keys.count > 1 {
          Picker("모니터", selection: Binding(get: { key }, set: { selected = $0 })) {
            ForEach(keys, id: \.self) { k in
              Text(store.configs[k]?.name ?? k) + Text(store.monitors.contains { $0.key == k } ? "" : " (연결 안 됨)")
            }
          }
          .frame(width: 320)
        } else {
          Text(store.configs[key]?.name ?? key).font(.headline)
        }
        InputList(key: key)
      }
    }
    .padding(20)
  }
}

struct InputList: View {
  @EnvironmentObject private var store: Store
  @AppStorage("thisMacMark") private var mark = ThisMacMark.fallback
  let key: String

  private var config: Binding<MonitorConfig> {
    Binding(get: { store.configs[key] ?? MonitorConfig(name: "", inputs: [], thisMac: nil, fromMonitor: false) },
            set: { store.configs[key] = $0 })
  }

  var body: some View {
    let c = config.wrappedValue
    VStack(alignment: .leading, spacing: 10) {
      Text(c.fromMonitor
           ? "모니터가 알려 준 입력 번호예요. 어느 기기가 꽂혀 있는지는 알 수 없으니 별칭을 붙여 주세요."
           : "이 모니터는 입력 번호 목록을 알려 주지 않아서 흔한 번호로 채웠어요. 안 되는 번호는 끄세요.")
        .foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)

      HStack {
        Text("메뉴").frame(width: 36)
        Text("번호").frame(width: 120, alignment: .leading)
        Text("별칭").frame(maxWidth: .infinity, alignment: .leading)
      }
      .font(.caption).foregroundStyle(.secondary)

      ScrollView {
        VStack(spacing: 6) {
          ForEach(config.inputs) { $slot in
            HStack {
              Toggle("", isOn: $slot.enabled).labelsHidden().frame(width: 36)
              VStack(alignment: .leading, spacing: 0) {
                Text("\(slot.code)" + (slot.code == c.thisMac ? "  \(mark) 현재 디스플레이" : "")).monospacedDigit()
                Text(InputSlot.standardName(slot.code).map { "표준: \($0)" } ?? "표준에 없는 번호")
                  .font(.caption2).foregroundStyle(.secondary)
              }
              .frame(width: 120, alignment: .leading)
              TextField("입력 \(slot.code)", text: $slot.name).textFieldStyle(.roundedBorder)
            }
          }
        }
      }

      HStack {
        if let m = store.monitors.first(where: { $0.key == key }) {
          Button(store.scanning.contains(key) ? "읽는 중…" : "모니터에서 번호 다시 읽기") {
            store.scanInputs(key: key, ddc: m.ddc)
          }
          .disabled(store.scanning.contains(key))
        }
        Spacer()
      }
      Text("「\(mark) 현재 디스플레이」는 이 맥에서 메뉴를 열었을 때 모니터가 보여 주던 입력이에요. 표준 이름은 참고용이고 모니터마다 다를 수 있어요.")
        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
  }
}
