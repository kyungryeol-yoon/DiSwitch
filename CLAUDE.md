# DiSwitch

**Di**splay **I**nput **Switch** — 맥에서 클릭 한 번으로 바깥 모니터의 **입력 소스**를 바꾸는 메뉴 막대 앱(DDC/CI).

- GitHub `kyungryeol-yoon/DiSwitch`(공개) — **범용**으로: 특정 사용자 환경에 맞춘 기본값·코드 금지. **커밋·푸시는 요청할 때만**. 커밋 작성자 이메일은 공개해도 됨(사용자 결정)
- Swift + SwiftPM + IOKit, 외부 라이브러리 없음, 애플 실리콘만(인텔은 방식이 달라 나중에), macOS 15+, Swift 5 언어 모드
- 번들 ID `io.github.kyungryeol-yoon.diswitch`(개인 앱 공통 규칙 `io.github.kyungryeol-yoon.<앱>`). v0.1.1에서 `app.displayinputswitch`에서 바꿈 — `LegacyDefaults.migrate()`가 첫 실행 때 옛 설정을 옮김. **옛 버전 사용자가 남아 있는 동안 지우지 말 것**
- 사용자용 설명은 `README.md`, 개발 메모는 이 파일. 설명은 한국어

## 동작 원리
- DDC/CI: I2C 주소 0x37, 서브주소 0x51. 체크섬 = 0x6E ^ 0x51 ^ 보낸 바이트 전부
  - 읽기 `0x82 0x01 VCP` → 50ms 뒤 11바이트(b[2]=0x02, b[3]=0 성공, b[4]=VCP, 최대 b[6..7], 지금 b[8..9])
  - 쓰기 `0x84 0x03 VCP 값상위 값하위` — **두 번 보냄**(한 번으론 놓치는 모니터가 있음)
  - 입력 소스 VCP `0x60`, 밝기 `0x10`. 기능 목록(capabilities) 명령 `0xF3` → `60(...)`에서 입력 번호를 가져옴
- 비공개 IOKit 함수: `IOAVServiceCreateWithService`(`DCPAVServiceProxy` 중 `Location = External`) · `IOAVServiceReadI2C` · `IOAVServiceWriteI2C` · `IOAVServiceCopyEDID`(모니터 이름 = EDID 0xFC 칸). macOS 업데이트에 바뀔 수 있음, 앱스토어 불가
- 모니터가 다른 입력을 보여 주는 동안에도 명령이 통함. 입력을 바꾸는 동안엔 읽기가 잠깐 응답 없음
- 포트에 무슨 기기가 꽂혔는지·신호가 있는지는 DDC로 알 수 없음(지금 입력 번호와 번호 목록만)
- **입력 번호는 모니터마다 표준과 다를 수 있음** → 표준표로 짐작하지 말고 기능 목록에서 가져옴(필립스 USB-C가 표준 27이 아니라 21 = 0x15. 기능 목록은 16진수)
- **신호 없는 입력으로 보내면 모니터가 신호 있는 입력을 스스로 찾아감**(필립스: 비어 있는 DP 15를 보내면 USB-C 21로 넘어감) → 「이 번호로 그 기기가 나온다」가 맞는 번호라는 증거가 아님. 넘긴 뒤 읽은 번호로 확인

## 구조(`Sources/DiSwitch/`, SwiftUI `MenuBarExtra`)
- `DDC.swift` 모니터 읽기/쓰기·기능 목록 해석 · `Store.swift` 상태·모니터별 설정 · `App.swift` 메뉴 · `SettingsView.swift` 설정창(일반·아이콘·입력) · `LegacyDefaults.swift` 옛 번들 ID 설정 옮기기
- `Sources/ddc.swift` — 시험용 명령줄(`swiftc -O -o ddc Sources/ddc.swift -framework IOKit` → `./ddc list` · `set <순번> <입력> [되돌릴 초]` · `caps <순번>`)

## 정한 것
- **모니터별 설정**(UserDefaults `monitors` = { EDID 8~15바이트 hex: MonitorConfig }): 입력 목록(번호·별칭·메뉴 표시) · `thisMac` · `fromMonitor`
  - 처음 보는 모니터 → 기능 목록에서 입력 번호를 가져옴(필립스 약 6초). 표준표에 있는 번호와 지금 입력만 보이게, 나머지는 숨김(이 맥의 입력이 표준표에 없을 수 있어서 — 맥북에서 필립스 21이 숨겨졌던 문제). 기능 목록이 없으면 흔한 번호(15·16·17·18·27)
  - 별칭이 비면 「입력 N」. 표준 이름은 설정창에 참고로만
  - 포트 종류(`InputSlot.port`, 옵셔널이라 옛 설정도 읽힘)는 사용자가 고름. 안 고르면 표준 이름을 흐리게, 표준에 없으면 「포트 모름」. USB-C는 MCCS 표준에 없음(27은 관례)
  - 같은 모델 두 대는 **일련번호가 있을 때만** EDID로 구분됨. 둘 다 0이면 열쇠가 겹쳐서 두 번째부터 출력 이름(IORegistry `DCPAVServiceProxy` 부모 이름 앞부분, 예 `dispext1`)을 붙임(`열쇠#dispext1`). 목록은 출력 이름 순. 한계: 같은 포트에 꽂으면 같은 출력이 잡히는지는 확인 못 함(같은 모델 두 대로 시험 안 함) → 포트를 바꿔 꽂으면 두 대의 설정이 서로 바뀔 수 있음. 이때 메뉴를 연 화면이 어느 쪽인지 몰라 `thisMac`도 기억 안 함
  - 화면 ↔ DDC 모니터 맞추기: EDID 8~9(제조사, 큰 끝) · 10~11(모델, 작은 끝) · 12~15(일련번호, 작은 끝) = `CGDisplayVendorNumber`·`ModelNumber`·`SerialNumber`
- **`thisMac`**(이 맥의 입력): 메뉴를 열 때 **마우스가 있는 화면이 그 모니터일 때만** 지금 입력을 기억. 다른 모니터에서 열면·앱을 켤 때·전환 뒤엔 기억 안 함(다른 모니터에서 열었을 때 틀리던 문제 때문). 처음 보는 모니터라 입력 목록을 읽는 중이면 `pendingThisMac`에 두었다가 목록이 생길 때 넣음. 3초 안에 다시 열면 다시 읽지 않고 방금 읽은 값으로 기억
- 로그인 자동 실행 스위치: 사용자가 눌렀을 때만 등록·해제(`Toggle`의 `Binding` set에서. `onChange`로 하면 상태를 다시 읽어 넣을 때 또 불려 오류가 지워지거나 허용 대기 항목을 지움). `.requiresApproval`은 켜짐으로 보이고 「로그인 항목 열기」 안내. Hum과 같은 방식
- 현재 디스플레이 표시(UserDefaults `thisMacMark`, 기본 ◀︎) · 메뉴 막대 아이콘은 SF Symbols에서 고름(기본 `display.2`, `rectangle.on.rectangle`은 미러링과 같아 뺌) · 로그인 자동 실행(`SMAppService`)
- 다시 읽는 때: 켤 때 · 메뉴 열 때 · 전환 4초 뒤 · 모니터 꽂기/빼기·배치 변경(2초 뒤) · 깨어남(3초 뒤). 모니터마다 따로·동시에 읽음(응답 없는 모니터가 다른 모니터를 막지 않음). 메뉴를 열 때는 응답 없던 모니터를 건너뜀, 「새로고침」은 전부
- 앱 아이콘: 어두운 바탕 + 모니터 두 대(뒤 주황·앞 파랑) + ⇄ 배지 — `packaging/make-icon.swift`

## 빌드·배포
- `./build.sh` → `build/DiSwitch.app` + zip. 버전 = `VERSION` > 가장 가까운 태그 `v*` > 0.0.0, 빌드 번호 = 커밋 수. ad-hoc 서명(개발자 서명·공증 안 함). MIT
- 태그 `vX.Y.Z` 푸시 → `.github/workflows/release.yml`(macos-26 + 최신 Xcode) → Release zip → `homebrew-tap`의 `Casks/diswitch.rb` 갱신(`TAP_TOKEN`, v0.1.1에서 자동 갱신 확인)
- cask 틀 `packaging/diswitch.rb`: `depends_on macos: :sequoia`, quarantine은 `postflight_steps`의 `run "/usr/bin/xattr"`로 지움(`writable_paths` 필요), `zap`은 `defaults delete`를 먼저(plist만 버리면 cfprefsd가 들고 있던 옛 설정이 살아남) + 옛 ID plist도
- 설치 `brew install --cask kyungryeol-yoon/tap/diswitch`. 새 버전이 안 보이면 `brew update` 먼저

## 시험 환경(이 맥 미니, 저장소엔 넣지 않음)
- 맥 미니 M4 — 필립스 32M2N8900(HDMI2) + BenQ GW2780(DDC 못 읽음)
- 필립스 입력 번호: HDMI1 = 17(닌텐도) · HDMI2 = 18(맥 미니) · USB-C = 21(맥북, 0x15). DP 15는 비어 있음. 기능 목록 `60(11 12 0F 15 21 22 2F 35)`
- 모니터가 새 입력에 화면을 잡는 데 몇 초 걸림 — 시험은 8~10초씩
- 맥북을 덮개 닫고(클램셸) 쓰면 모니터가 다른 입력에 가 있는 동안 잠듦 → 돌아와도 「신호 없음」

## 다음에 할 것
- [ ] 로그인 자동 실행: 재시동해서 뜨는지 확인(v0.1.2에서 다시 켬 — 로그인 항목에 DiSwitch 하나만, 옛 항목 안 남음 확인)
- [ ] 맥북에서 시험: 덮개 닫고 입력 넘겼다 돌아올 때 잠드는지(`pmset -g log | grep -E " Sleep | Wake "`) → 깨우기 방법 정하기
- [ ] BenQ 화면에서 메뉴 열기 시험: ✓는 필립스가 보여 주는 입력, 현재 디스플레이 표시는 맥 미니(18) 그대로인지
- 계획: ① 전역 단축키 ② 입력 번호 찾기(번호를 하나씩 보내고 8초 뒤 자동 복귀 → 「방금 무엇이 보였나요?」) ③ (선택) 한 모니터를 맥 여러 대가 쓸 때 앱끼리 네트워크로 서로 찾기·덮개 닫은 맥북 깨우기 ④ `ddc.swift`와 앱 DDC 코드 중복 정리
