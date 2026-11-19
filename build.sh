#!/bin/zsh
# 빌드해서 build/DisplayInputSwitch.app 과 GitHub Releases에 올릴 zip을 만든다(Xcode 프로젝트 없이 swift build만)
#   ./build.sh           빌드 + zip
#   ./build.sh install   빌드 + zip + 「응용 프로그램」 폴더에 복사하고 다시 실행
set -euo pipefail
cd "$(dirname "$0")"
VERSION=0.1
swift build -c release
APP=build/DisplayInputSwitch.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"
cp .build/release/DisplayInputSwitch "$APP/Contents/MacOS/"
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key><string>DisplayInputSwitch</string>
  <key>CFBundleIdentifier</key><string>app.displayinputswitch</string>
  <key>CFBundleName</key><string>DisplayInputSwitch</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>1</string>
  <key>LSMinimumSystemVersion</key><string>15.0</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST
# 애플 개발자 서명 없이 임시(ad-hoc) 서명 — 받은 사람은 처음 한 번 「그래도 열기」가 필요
codesign --force --sign - "$APP"
ZIP=build/DisplayInputSwitch-$VERSION.zip
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"
echo "만듦: $APP · $ZIP"

if [[ "${1:-}" == install ]]; then
  pkill -x DisplayInputSwitch || true
  rm -rf /Applications/DisplayInputSwitch.app
  cp -R "$APP" /Applications/
  open /Applications/DisplayInputSwitch.app
  echo "설치: /Applications/DisplayInputSwitch.app"
fi
