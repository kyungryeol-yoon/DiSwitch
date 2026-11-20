# DiSwitch

**Di**splay **I**nput **Switch** — 맥 메뉴 막대에서 클릭 한 번으로 바깥 모니터의 **입력 소스**(HDMI·DisplayPort·USB-C …)를 바꾸는 앱이에요.
모니터 버튼을 더듬어 메뉴를 찾을 필요 없이, 맥·노트북·게임기를 오가며 쓸 수 있어요.

*A tiny macOS menu bar app that switches your external monitor's input source over DDC/CI. Apple silicon, macOS 15+, no dependencies.*

## 기능
- 메뉴 막대에서 모니터별로 입력을 고르면 바로 바뀌어요. 지금 입력에는 체크 표시가 붙어요.
- 처음 켤 때 **모니터에게 입력 번호 목록을 물어서** 메뉴를 만들어요. 모니터에 없는 번호는 나오지 않아요.
- 입력마다 별칭을 붙일 수 있어요(예: `MacBook Pro`, `Nintendo Switch 2`).
- 현재 디스플레이(이 맥이 연결된 입력)에 표시를 붙여요(◀ ★ 📍 등, 이모지·글자로 바꿀 수 있어요).
- 메뉴 막대 아이콘을 SF Symbols 중에서 골라 바꿀 수 있어요.
- 로그인할 때 자동으로 실행할 수 있어요.

## 필요한 것
- **애플 실리콘 맥**(M1 이상). 인텔 맥은 아직 지원하지 않아요.
- macOS 15 이상
- **DDC/CI를 지원하는 모니터**(대부분의 모니터가 지원해요. 모니터 메뉴에서 DDC/CI가 꺼져 있으면 켜 주세요)

## 설치
### Homebrew
```sh
brew install --cask kyungryeol-yoon/tap/diswitch
```
업데이트는 `brew upgrade`, 지우기는 `brew uninstall --cask diswitch`.

### 직접 받기
1. [Releases](../../releases)에서 `DiSwitch-<버전>.zip`을 받아 풀어요.
2. `DiSwitch.app`을 「응용 프로그램」 폴더로 옮겨요.
3. 처음 열 때 「확인되지 않은 개발자」 경고가 나오면:
   **시스템 설정 → 개인정보 보호 및 보안** 아래쪽의 **「그래도 열기」**를 눌러요. 한 번만 하면 돼요.
   (애플 개발자 서명과 공증을 하지 않은 앱이라 그래요.)

## 쓰는 법
1. 메뉴 막대의 아이콘을 누르면 모니터별 입력 목록이 나와요. 처음엔 「입력 17」처럼 번호로 나와요.
2. **설정… → 입력** 탭에서 번호마다 별칭을 붙이고, 메뉴에 보일 입력을 골라요.
   - 번호 옆의 「표준: HDMI 1」 같은 이름은 참고용이에요. 모니터마다 다를 수 있어요.
   - 어느 번호가 어느 기기인지 모르겠으면 메뉴에서 하나씩 눌러 화면을 확인해 보세요.

## 알아 둘 점
- **어느 포트에 무슨 기기가 꽂혀 있는지는 알 수 없어요.** 모니터는 DDC로 「지금 보여 주는 입력 번호」와 「있는 입력 번호 목록」만 알려 줘요. 별칭은 직접 붙여야 해요.
- **입력 번호가 표준과 다른 모니터가 있어요.** 예: Philips 32M2N8900은 USB-C가 표준 번호 27이 아니라 15(표준에서는 DisplayPort 1)예요.
- 입력 번호 목록을 알려 주지 않는 모니터는 흔한 번호(15·16·17·18·27)로 채워요. 안 되는 번호는 설정에서 끄세요.
- 다른 입력으로 넘어간 뒤 새 화면이 나오기까지 몇 초 걸릴 수 있어요.
- 덮개를 닫고 쓰는 맥북은 모니터가 다른 입력으로 넘어가면 잠들 수 있어요.
- macOS의 공개되지 않은 IOKit 함수(`IOAVService…`)를 써요. 그래서 앱 스토어에는 올릴 수 없고, macOS 업데이트로 동작이 바뀔 수 있어요.

## 소스에서 빌드
Xcode(또는 Command Line Tools)가 있으면 돼요. 외부 라이브러리는 없어요.

```sh
./build.sh            # build/DiSwitch.app 과 배포용 zip 생성
./build.sh install    # 빌드 후 /Applications 에 복사하고 실행
```

## 릴리스(관리자용)
`v1.2.3` 형식의 태그를 올리면 GitHub Actions가 빌드해서 Release를 만들고 Homebrew tap을 갱신해요.
```sh
git tag v0.1.0 && git push origin v0.1.0
```
tap 갱신에는 저장소 Secret `TAP_TOKEN`(`homebrew-tap` 저장소에 쓰기 권한이 있는 토큰)이 필요해요.

## 라이선스
[MIT](LICENSE)

## 동작 원리
DDC/CI(모니터 I2C 주소 `0x37`)로 VCP 코드 `0x60`(입력 소스)을 읽고 써요. 입력 번호 목록은 기능 목록(capabilities, 명령 `0xF3`)의 `60(...)` 부분에서 가져와요.
애플 실리콘에서는 IORegistry의 `DCPAVServiceProxy`(`Location = External`)로 `IOAVServiceReadI2C` / `IOAVServiceWriteI2C`를 불러요.
