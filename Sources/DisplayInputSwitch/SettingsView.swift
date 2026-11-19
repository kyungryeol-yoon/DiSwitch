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
  @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
  @State private var error: String?

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Toggle("로그인할 때 자동으로 실행", isOn: $launchAtLogin)
        .onChange(of: launchAtLogin) { _, on in setLaunchAtLogin(on) }
      Text("「시스템 설정 → 일반 → 로그인 항목」에서도 끄고 켤 수 있어요.")
        .font(.caption).foregroundStyle(.secondary)
      if let error { Text(error).foregroundStyle(.red).font(.caption) }
      Spacer()
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .onAppear { launchAtLogin = SMAppService.mainApp.status == .enabled }
  }

  private func setLaunchAtLogin(_ on: Bool) {
    do {
      if on { try SMAppService.mainApp.register() } else { try SMAppService.mainApp.unregister() }
      error = nil
    } catch {
      self.error = "바꾸지 못함: \(error.localizedDescription)"
    }
    launchAtLogin = SMAppService.mainApp.status == .enabled
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
                Text("\(slot.code)" + (slot.code == c.thisMac ? "  · 이 맥" : "")).monospacedDigit()
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
      Text("「이 맥」은 이 맥에서 메뉴를 열었을 때 모니터가 보여 주던 입력이에요. 표준 이름은 참고용이고 모니터마다 다를 수 있어요.")
        .font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
    }
  }
}
