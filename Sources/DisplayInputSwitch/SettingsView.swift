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

  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      Text("메뉴에 보일 입력").font(.headline)
      Text("이름은 마음대로 붙이세요(예: 맥북, 닌텐도). 번호는 모니터마다 표준과 다를 수 있어요.")
        .foregroundStyle(.secondary)

      HStack {
        Text("보임").frame(width: 36)
        Text("이름").frame(maxWidth: .infinity, alignment: .leading)
        Text("번호").frame(width: 60, alignment: .leading)
        Spacer().frame(width: 24)
      }
      .font(.caption).foregroundStyle(.secondary)

      ScrollView {
        VStack(spacing: 6) {
          ForEach($store.inputs) { $slot in
            HStack {
              Toggle("", isOn: $slot.enabled).labelsHidden().frame(width: 36)
              TextField("이름", text: $slot.name).textFieldStyle(.roundedBorder)
              TextField("번호", value: $slot.code, format: .number.grouping(.never))
                .textFieldStyle(.roundedBorder).frame(width: 60)
              Button { store.inputs.removeAll { $0.id == slot.id } } label: {
                Image(systemName: "minus.circle")
              }
              .buttonStyle(.borderless).frame(width: 24)
            }
          }
        }
      }

      HStack {
        Button("입력 추가") { store.inputs.append(InputSlot(name: "새 입력", code: 0)) }
        Button("기본값으로") { store.inputs = InputSlot.defaults }
        Spacer()
      }
      Text("표준 번호: DisplayPort 1 = 15 · DisplayPort 2 = 16 · HDMI 1 = 17 · HDMI 2 = 18 · USB-C = 27")
        .font(.caption).foregroundStyle(.secondary)
    }
    .padding(20)
  }
}
