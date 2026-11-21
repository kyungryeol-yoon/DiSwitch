import ServiceManagement
import SwiftUI

// 설정창은 Hum·MacInv와 같은 모양: Form + .grouped(시스템 설정처럼 둥근 묶음), 설명은 묶음 아래 footer

struct SettingsView: View {
  var body: some View {
    TabView {
      GeneralSettings().tabItem { Label("일반", systemImage: "gearshape") }
      IconSettings().tabItem { Label("아이콘", systemImage: "paintbrush") }
      InputSettings().tabItem { Label("입력", systemImage: "list.bullet") }
    }
    .frame(width: 600, height: 540)
  }
}

private func footnote(_ s: String) -> some View {
  Text(s).font(.caption).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
}

/// 카드 — Hum·MacInv와 같은 값(둥근 10, 옅은 바탕, 얇은 테두리)
private struct Card<Content: View>: View {
  var title: String?
  @ViewBuilder let content: () -> Content
  var body: some View {
    VStack(alignment: .leading, spacing: 10) {
      if let title { Text(title).font(.headline) }
      content()
    }
    .padding(.horizontal, 14).padding(.vertical, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.primary.opacity(0.05), in: RoundedRectangle(cornerRadius: 10))
    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Color.primary.opacity(0.08)))
  }
}

/// 고를 수 있는 칸(아이콘·표시 후보) — 고른 것은 강조색 테두리
private struct ChoiceTile<Label: View>: View {
  let selected: Bool
  let width: CGFloat
  let height: CGFloat
  let action: () -> Void
  @ViewBuilder let label: () -> Label

  var body: some View {
    Button(action: action) {
      label()
        .frame(width: width, height: height)
        .background(RoundedRectangle(cornerRadius: 8).fill(selected ? Color.accentColor.opacity(0.22) : Color.primary.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(selected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: selected ? 2 : 1))
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
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

  private var version: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "개발판" }

  var body: some View {
    // 카드를 왼쪽·오른쪽으로 놓아 빈 곳을 줄임
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .top, spacing: 12) {
        Card {
          HStack {
            Text("로그인할 때 자동으로 실행")
            Spacer()
            // 사용자가 눌렀을 때만 등록·해제(상태를 다시 읽어 넣을 때 또 불리지 않게 onChange 대신 Binding의 set에서)
            Toggle("", isOn: Binding(get: { launchAtLogin }, set: { setLaunchAtLogin($0) }))
              .toggleStyle(.switch).labelsHidden()
          }
          loginFooter
        }
        Card {
          Text("DiSwitch \(version)")
          Link("GitHub", destination: URL(string: "https://github.com/kyungryeol-yoon/DiSwitch")!).font(.callout)
        }
        .frame(width: 150)
      }
      .fixedSize(horizontal: false, vertical: true)

      Card(title: "현재 디스플레이 표시") {
        HStack(alignment: .top, spacing: 16) {
          VStack(alignment: .leading, spacing: 10) {
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(44), spacing: 8), count: 6), alignment: .leading, spacing: 8) {
              ForEach(ThisMacMark.candidates, id: \.self) { m in
                ChoiceTile(selected: mark == m, width: 44, height: 34, action: { mark = m }) {
                  Text(m).font(.system(size: 17))
                }
              }
            }
            HStack {
              TextField("직접 입력", text: $custom, prompt: Text("직접 입력(이모지·글자)"))
                .textFieldStyle(.roundedBorder).frame(width: 190)
                .onSubmit(applyCustom)
              Button("적용", action: applyCustom).disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
            }
          }
          VStack(alignment: .leading, spacing: 6) {
            Text("미리보기").font(.caption).foregroundStyle(.secondary)
            MenuPreview(mark: mark, names: previewNames)
          }
        }
        footnote("메뉴에서 이 Mac이 연결된 입력 옆에 붙어요. 이모지는 ⌃⌘Space로 넣을 수 있어요.")
      }
      Spacer(minLength: 0)
    }
    .padding(20)
    .onAppear(perform: readLaunchAtLogin)
    // 시스템 설정에서 로그인 항목을 바꿨을 수 있으니 창이 앞으로 올 때마다 다시 읽음
    .onReceive(NotificationCenter.default.publisher(for: NSWindow.didBecomeKeyNotification)) { _ in readLaunchAtLogin() }
  }

  @ViewBuilder private var loginFooter: some View {
    if let error {
      Text(error).font(.caption).foregroundStyle(.red)
    } else if needsApproval {
      HStack(spacing: 6) {
        Text("시스템 설정 → 일반 → 로그인 항목에서 DiSwitch를 허용해야 켜져요.").font(.caption).foregroundStyle(.orange)
        Button("열기") { SMAppService.openSystemSettingsLoginItems() }.buttonStyle(.link).font(.caption)
      }
    } else {
      footnote("시스템 설정 → 일반 → 로그인 항목에서도 바꿀 수 있어요.")
    }
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
      self.error = "바꾸지 못했어요: \(error.localizedDescription)"
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
    VStack(alignment: .leading, spacing: 5) {
      HStack(spacing: 6) { Text("✓").frame(width: 12); Text(names.mine + "  " + mark) }
      ForEach(names.others, id: \.self) { n in HStack(spacing: 6) { Text("").frame(width: 12); Text(n) } }
    }
    .font(.system(size: 13))
    .padding(.horizontal, 12).padding(.vertical, 8)
    .frame(minWidth: 170, alignment: .leading)
    .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.primary.opacity(0.08)))
  }
}

// MARK: - 아이콘

struct IconSettings: View {
  @AppStorage("menuIcon") private var icon = MenuIcon.fallback
  @State private var custom = ""

  var body: some View {
    Form {
      Section {
        HStack(spacing: 12) {
          MenuBarPreview(symbol: icon, dark: false)
          MenuBarPreview(symbol: icon, dark: true)
          Spacer()
        }
      } header: {
        Text("메뉴 막대에서 보기")
      }

      Section {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 58), spacing: 8)], alignment: .leading, spacing: 8) {
          ForEach(MenuIcon.candidates, id: \.self) { name in
            // 기호마다 그림 크기가 달라 작은 것(네모 안 화살표 등)도 잘 보이게 칸을 꽉 채우는 크기로
            ChoiceTile(selected: icon == name, width: 58, height: 48, action: { icon = name }) {
              Image(systemName: name).font(.system(size: 22)).imageScale(.large)
            }
            .help(name)
          }
        }
        .padding(.vertical, 4)
      } header: {
        Text("아이콘")
      } footer: {
        footnote("누르면 메뉴 막대 아이콘이 바로 바뀌어요.")
      }

      Section {
        HStack {
          TextField("이름", text: $custom, prompt: Text("예: display.2"))
            .onSubmit(applyCustom)
          if MenuIcon.exists(custom) {
            Image(systemName: custom).font(.system(size: 16)).frame(width: 24)
            Button("적용", action: applyCustom)
          } else if !custom.isEmpty {
            Text("그런 이름 없음").foregroundStyle(.red)
          }
        }
      } header: {
        Text("SF Symbols 이름으로 직접 넣기")
      } footer: {
        footnote("지금: \(icon)").textSelection(.enabled)
      }
    }
    .formStyle(.grouped)
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
      Image(nsImage: MenuIcon.image(symbol))   // 메뉴 막대에 실제로 올라가는 그림과 같은 크기
      Image(systemName: "magnifyingglass")
    }
    .font(.system(size: 15))
    .foregroundStyle(dark ? .white : .black)
    .padding(.horizontal, 12)
    .frame(height: 28)
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
    // 입력이 많은 모니터만 스크롤되게(보통은 한 화면에 다 들어옴)
    ScrollView {
      VStack(alignment: .leading, spacing: 12) {
        if keys.isEmpty {
          Card {
            Text(store.scanning.isEmpty ? "DDC로 제어할 수 있는 모니터가 없어요." : "모니터에서 입력 번호를 읽는 중…")
              .foregroundStyle(.secondary)
          }
        } else {
          let key = selected.flatMap { keys.contains($0) ? $0 : nil } ?? keys[0]
          // 모니터 이름 옆에 「다시 읽기」(빈 곳 활용)
          Card {
            HStack {
              if keys.count > 1 {
                Picker("모니터", selection: Binding(get: { key }, set: { selected = $0 })) {
                  ForEach(keys, id: \.self) { k in
                    Text(store.configs[k]?.name ?? k) + Text(store.monitors.contains { $0.key == k } ? "" : " (연결 안 됨)")
                  }
                }
                .frame(maxWidth: 300)
              } else {
                Text("모니터").foregroundStyle(.secondary)
                Text(store.configs[key]?.name ?? key).font(.headline)
              }
              Spacer()
              if let m = store.monitors.first(where: { $0.key == key }) {
                Button(store.scanning.contains(key) ? "읽는 중…" : "모니터에서 번호 다시 읽기") {
                  store.scanInputs(key: key, ddc: m.ddc, current: m.current)
                }
                .disabled(store.scanning.contains(key))
              }
            }
          }
          InputList(key: key)
        }
      }
      .padding(20)
    }
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
    VStack(alignment: .leading, spacing: 8) {
      Card {
        VStack(spacing: 0) {
          HStack(spacing: 10) {
            Text("메뉴").frame(width: 36)
            Text("번호").frame(width: 56, alignment: .leading)
            Text("포트").frame(width: 150, alignment: .leading)
            Text("별칭")
            Spacer()
          }
          .font(.caption).foregroundStyle(.secondary)
          .padding(.bottom, 6)
          // 한 줄에 하나(체크 · 번호 · 포트 · 별칭)
          ForEach(config.inputs) { $slot in
            Divider()
            HStack(spacing: 10) {
              Toggle("", isOn: $slot.enabled).toggleStyle(.checkbox).labelsHidden().frame(width: 36)
              HStack(spacing: 4) {
                Text("\(slot.code)").monospacedDigit()
                if slot.code == c.thisMac { Text(mark).help("현재 디스플레이(이 Mac이 연결된 입력)") }
              }
              .frame(width: 56, alignment: .leading)
              // 포트 종류는 모니터가 알려 주지 않으니 사용자가 고름(표준표와 다른 모니터가 있어서)
              Menu {
                ForEach(InputSlot.portChoices, id: \.self) { p in
                  Button { slot.port = p } label: {
                    if slot.port == p { Label(p, systemImage: "checkmark") } else { Text(p) }
                  }
                }
                Divider()
                Button(InputSlot.standardName(slot.code).map { "표준대로(\($0))" } ?? "모름") { slot.port = nil }
              } label: {
                Text(slot.portLabel).font(.callout)
              }
              .menuStyle(.borderlessButton).fixedSize()
              .foregroundStyle(slot.port == nil ? .secondary : .primary)
              .frame(width: 150, alignment: .leading)
              .help("이 번호가 어느 포트인지 고르세요")
              TextField("별칭", text: $slot.name, prompt: Text("입력 \(slot.code)"))
                .textFieldStyle(.plain).labelsHidden()
            }
            .padding(.vertical, 5)
          }
        }
      }
      footnote((c.fromMonitor
                ? "모니터가 알려 준 입력 번호예요. 어느 기기가 꽂혀 있는지는 알 수 없으니 별칭을 붙여 주세요."
                : "이 모니터는 입력 번호 목록을 알려 주지 않아서 흔한 번호로 채웠어요. 안 되는 번호는 끄세요.")
               + " 포트를 눌러 종류를 고를 수 있어요. 번호 옆 \(mark)는 현재 디스플레이(이 Mac이 연결된 입력)예요. 표준 이름은 참고용이에요.")
        .padding(.horizontal, 4)
    }
  }
}
