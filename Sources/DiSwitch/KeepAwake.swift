import IOKit.pwr_mgt

/// 모니터가 다른 입력을 보여 주는 동안 이 맥이 잠들지 않게 함(영상을 틀어 둔 것과 같은 효과).
/// 덮개를 닫은 맥북은 잠들면 모니터를 이 맥으로 돌려도 「신호 없음」 → 키보드로 깨워야 했음.
/// power assertion은 공개 API라 권한·서명 조건이 없고, 시스템 설정을 바꿀 때 뜨는 배터리 경고도 없음.
/// `pmset -g assertions`에 DiSwitch 이름으로 보임. 앱이 끝나면 저절로 풀림
@MainActor
final class KeepAwake {
  private var ids: [IOPMAssertionID] = []
  private var activityID: IOPMAssertionID = 0

  var isOn: Bool { !ids.isEmpty }

  func set(_ on: Bool) {
    guard on != isOn else { return }
    if on {
      // 화면 끄기를 막으면 시스템 잠들기도 막힘. PreventSystemSleep은 전원 연결 중에만 통함(덮개 닫은 맥북 대비)
      for type in ["PreventUserIdleDisplaySleep", "PreventSystemSleep"] {
        var id: IOPMAssertionID = 0
        let r = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn),
                                            "DiSwitch: 모니터가 다른 입력을 보여 주는 중" as CFString, &id)
        if r == kIOReturnSuccess { ids.append(id) }
      }
    } else {
      ids.forEach { IOPMAssertionRelease($0) }
      ids = []
    }
  }

  /// 키보드를 누른 것처럼 사용자 활동을 알림 — 화면이 꺼져 있으면 켜고, 잠들기 시간을 처음부터 다시 셈
  /// (막아 둔 걸 풀자마자 오래 안 쓴 것으로 쳐서 바로 화면이 꺼지지 않게)
  func declareActivity() {
    IOPMAssertionDeclareUserActivity("DiSwitch: 모니터가 이 맥으로 돌아옴" as CFString, kIOPMUserActiveLocal, &activityID)
  }
}
