# Homebrew cask 틀 — 릴리스할 때 GitHub Actions가 __VERSION__·__SHA256__을 채워 homebrew-tap/Casks/ 에 올림
cask "diswitch" do
  version "__VERSION__"
  sha256 "__SHA256__"

  url "https://github.com/kyungryeol-yoon/DiSwitch/releases/download/v#{version}/DiSwitch-#{version}.zip"
  name "DiSwitch"
  desc "Menu bar app to switch an external monitor's input source over DDC/CI"
  homepage "https://github.com/kyungryeol-yoon/DiSwitch"

  depends_on arch: :arm64
  depends_on macos: ">= :sequoia"

  app "DiSwitch.app"

  # 애플 개발자 서명·공증을 하지 않은 앱이라, 「확인되지 않은 개발자」 경고 없이 열리도록 격리 표시를 지움
  postflight do
    system_command "/usr/bin/xattr",
                   args: ["-dr", "com.apple.quarantine", "#{appdir}/DiSwitch.app"],
                   sudo: false
  end

  uninstall quit: "app.displayinputswitch"

  zap trash: "~/Library/Preferences/app.displayinputswitch.plist"
end
