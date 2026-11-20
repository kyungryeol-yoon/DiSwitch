# DiSwitch

> 이름: **DiSwitch** = **Di**splay **I**nput **Switch**(2026-11-20, 「DisplayInputSwitch」가 앱 목록에서 잘려서 바꿈). 저장소·zip·cask·앱 이름 모두 DiSwitch. **번들 ID만 `app.displayinputswitch` 그대로**(바꾸면 저장된 설정이 사라짐). 로컬 폴더도 `macos/DiSwitch`(2026-11-20 옮김)

맥에서 클릭 한 번(메뉴 막대·단축키)으로 바깥 모니터의 **입력 소스**를 바꾸는 앱. GitHub에 **범용**으로 공개(2026-11-19 시작) — 특정 사용자 환경에 맞춘 기본값·코드를 넣지 말 것
- git main → GitHub `origin`(공개 저장소). **커밋·푸시는 사용자가 요청할 때만**. 커밋 작성자 이메일은 개인 메일 그대로 공개해도 됨(사용자 결정)
- 사용자용 설명은 `README.md`(공개), 개발 메모는 이 파일
- 외부 라이브러리 없이 직접(Swift + macOS의 IOKit). 애플 실리콘만(인텔 맥은 방식이 달라 나중에)
- 설명은 한국어

## 동작 원리(2026-11-19 시험으로 확인)
- DDC/CI: 모니터 I2C 주소 0x37, 서브주소 0x51. 체크섬 = 0x6E ^ 0x51 ^ 보낸 바이트 전부
  - 읽기 `0x82 0x01 VCP` → 50ms 뒤 11바이트(b[2]=0x02, b[3]=0 성공, b[4]=VCP, 최대 b[6..7], 지금 b[8..9])
  - 쓰기 `0x84 0x03 VCP 값상위 값하위` (두 번 보냄 — 한 번으론 놓치는 모니터가 있음)
  - 입력 소스 VCP `0x60`, 밝기 `0x10`
- 공개 안 된 IOKit 함수: `IOAVServiceCreateWithService`(IORegistry `DCPAVServiceProxy` 중 `Location = External`) · `IOAVServiceReadI2C` · `IOAVServiceWriteI2C` · `IOAVServiceCopyEDID`(모니터 이름 = EDID 0xFC 칸). macOS 업데이트에 바뀔 수 있음, 앱스토어 불가
- 모니터가 다른 입력을 보여 주는 동안에도 명령이 통함(맥 미니 HDMI2에서 USB-C로 넘겼다가 되돌리기 확인). 입력을 바꾸는 동안엔 읽기가 잠깐 응답 없음

## 사용자 환경(시험한 것)
- 맥 미니 M4 — 필립스 **32M2N8900**(HDMI2) + BenQ GW2780(DDC 못 읽음, 전환 대상 아님)
- 필립스 입력 번호: HDMI1 = **17**(닌텐도 — 꺼져 있어 화면은 확인 못 함) · HDMI2 = **18**(맥 미니) · USB-C = **15**(맥북 — 표준 USB-C 번호 27이 아니라 「DisplayPort 1」 번호. 27·16은 반응 없음)
  - → 모니터마다 번호가 표준과 다를 수 있음. 그래서 표준표로 짐작하지 말고 **모니터의 기능 목록에서 번호를 가져옴**(0.1에서 표준 27을 USB-C로 넣었다가 안 넘어간 일이 있었음)
- 이 맥 미니 앱 설정의 별칭(UserDefaults, 저장소엔 없음): 15 = MacBook Pro 16-inch (M1 Pro) · 17 = Nintendo Switch 2 · 18 = Mac mini (M4)
- 모니터가 새 입력에 화면을 잡는 데 몇 초 걸림 — 시험은 8~10초씩, 3초면 못 봄
- 맥북은 덮개를 닫은 채(클램셸) 쓰면, 모니터가 다른 입력으로 가 있는 동안 잠듦 → 돌아와도 「신호 없음」. **맥북으로 넘길 때 깨우기**가 필요(키보드 누르기 / 맥북에도 앱을 깔아 네트워크로 깨우기 등 — 정할 것)

## 지금 있는 것
- 메뉴 막대 앱 `Sources/DiSwitch/`(SwiftPM + SwiftUI `MenuBarExtra`, macOS 15+, Swift 5 언어 모드)
  - `DDC.swift` 모니터 읽기/쓰기·기능 목록 읽기와 `60(...)` 해석 · `Store.swift` 상태·모니터별 설정 · `App.swift` 메뉴 · `SettingsView.swift` 설정창(일반·아이콘·입력 탭)
  - **모니터별 설정**(UserDefaults `monitors` = { EDID 8~15바이트 hex(제조사·모델·일련번호): MonitorConfig }): 입력 목록(번호·별칭·메뉴에 보임) · `thisMac` · `fromMonitor`
    - 처음 보는 모니터 → 기능 목록에서 입력 번호를 가져와 만듦(필립스 약 6초). 표준표에 있는 번호만 보이게, 나머지(21·33…)는 숨김. 기능 목록이 없으면 흔한 번호(15·16·17·18·27)
    - 별칭이 비면 「입력 N」. 표준 이름은 설정창에 참고로만 표시
    - `thisMac`: 메뉴를 열 때 **마우스가 있는 화면이 그 모니터일 때만** 지금 입력을 기억(그 화면을 보고 메뉴를 열었다 = 이 맥 화면이 보이는 중). 다른 모니터(BenQ)에서 열면 기억 안 함 — 처음엔 「메뉴를 열면 무조건」이었다가, 필립스가 맥북을 보여 주는 동안 BenQ에서 메뉴를 열면 틀리는 걸 발견(2026-11-20). 앱을 켤 때·전환 뒤에도 기억 안 함
    - 화면 ↔ DDC 모니터 맞추기: EDID 8~9(제조사, 큰 끝) · 10~11(모델, 작은 끝) · 12~15(일련번호, 작은 끝) = `CGDisplayVendorNumber`·`ModelNumber`·`SerialNumber`(필립스 410C·C34C·76069로 확인)
    - 0.1의 모니터 공통 목록(UserDefaults `inputs`)은 처음 한 번 옮기고 지움
  - 다시 읽는 때: 켤 때 · 메뉴 열 때 · 전환 4초 뒤 · 모니터 꽂기/빼기·화면 배치 변경(2초 뒤) · 잠자기에서 깨어남(3초 뒤)
  - 모니터마다 따로·동시에 읽음(응답 없는 모니터가 24초 걸려도 다른 모니터는 바로). 메뉴를 열 때는 응답 없던 모니터를 건너뜀, 「새로고침」은 전부
  - 설정 「일반」 탭: 로그인할 때 자동 실행(SMAppService)
  - 현재 디스플레이 표시(= thisMac 입력, UserDefaults `thisMacMark`, 기본 ◀︎ 흑백): 설정 「일반」 탭에서 후보·직접 입력, 메뉴 미리보기
  - 메뉴 막대 아이콘은 설정창에서 SF Symbols 후보를 고르거나 이름을 넣어 바꿈. 기본 `display.2`(`rectangle.on.rectangle`은 화면 미러링과 같아서 후보에서 뺌)
- 빌드: `./build.sh` → `build/DiSwitch.app` + `build/DiSwitch-<버전>.zip`(+ sha256 출력) · `./build.sh install` → /Applications에 복사·재실행
  - 앱 아이콘: `packaging/AppIcon.icns`(사용자가 고른 「T1」 — 어두운 바탕, 모니터 두 대 겹침(뒤 주황·앞 파랑, 단색 판+발 받침), 흰 동그라미 ⇄ 배지). 그리는 코드 `packaging/make-icon.swift`(크기마다 다시 그림)
  - 버전 = 환경 변수 `VERSION` > 가장 가까운 git 태그 `v*` > 0.0.0. 빌드 번호 = 커밋 수
  - 애플 개발자 서명·공증은 **안 함**(ad-hoc 서명). 라이선스 MIT(저작권자 「Yoon」)
- 배포(2026-11-20 정함): **태그 `vX.Y.Z` 푸시 → `.github/workflows/release.yml`**(macos-15 러너)이 빌드 → GitHub Release에 zip → `kyungryeol-yoon/homebrew-tap`(공개)의 `Casks/diswitch.rb` 갱신
  - cask 틀은 `packaging/diswitch.rb`(postflight에서 quarantine 지움 → 「그래도 열기」 없이 열림), 릴리스 설명은 `packaging/release-notes.md`
  - tap 갱신엔 이 저장소 Secret `TAP_TOKEN` 필요(없으면 건너뜀). tap 저장소 하나에 앞으로 만들 앱도 다 넣음
  - 설치: `brew install --cask kyungryeol-yoon/tap/diswitch`
- `Sources/ddc.swift` — 시험용 명령줄(`swiftc -O -o ddc Sources/ddc.swift -framework IOKit`)
  - `./ddc list` 모니터 이름·입력·밝기(읽기만) · `./ddc set <순번> <입력> [되돌릴 초]` · `./ddc caps <순번>` 기능 목록
- 기능 목록(capabilities, 명령 0xF3): 필립스는 `60(11 12 0F 15 21 22 2F 35)`(17·18·15는 확인, 21·33·34·47·53은 모름). BenQ는 0바이트
  - 어느 포트에 무슨 기기가 꽂혔는지·신호가 있는지는 DDC로 알 수 없음(지금 보여 주는 입력 번호와 번호 목록만)

## 다음 세션에서 이어서 할 것(2026-11-20 기준)
- [x] 이름 변경·아이콘·LICENSE·자동 릴리스 등 커밋·푸시, 저장소 이름 `DiSwitch`·`homebrew-tap` 만들기·remote 주소·로컬 폴더 이동(2026-11-20)
- [ ] `TAP_TOKEN` Secret이 들어갔는지 확인(없으면 릴리스는 되고 tap 갱신만 건너뜀)
- [ ] `v0.1.0` 태그 푸시 → Actions 결과 확인 → `brew install --cask kyungryeol-yoon/tap/diswitch`로 이 맥에서 설치 시험(quarantine 지우기·로그인 항목 포함)
- [ ] 맥북에서 시험: 덮개 닫고 입력 넘겼다 돌아올 때 잠드는지(`pmset -g log | grep -E " Sleep | Wake "`) — 맥북 설정(잠금 화면·배터리 옵션)은 안내함
- [ ] 메뉴에서 BenQ 화면으로 메뉴 열기 시험: ✓는 필립스가 보여 주는 입력, 현재 디스플레이 표시는 맥 미니(18) 그대로인지

## 할 일(계획)
1. 전역 단축키
2. 입력 번호 찾기 — 기능 목록에 있는 번호를 하나씩 보내고 8초쯤 뒤 자동 복귀 → 맥 화면에서 「방금 무엇이 보였나요?」(넘어가 있는 동안엔 맥 화면이 안 보여 팝업 불가)
3. (선택 기능) 한 모니터를 맥 여러 대가 쓸 때 — 앱끼리 같은 네트워크에서 서로 찾아 「나는 N번」을 주고받고, 덮개 닫은 맥북 깨우기(잠자기 막기 또는 네트워크로 깨우기, 맥북에서 시험 필요)
4. 시험용 `ddc.swift`와 앱 DDC 코드 중복 정리(급하지 않음)
