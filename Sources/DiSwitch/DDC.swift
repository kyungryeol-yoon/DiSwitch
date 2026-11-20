// DDC/CI — 애플 실리콘 맥에서 바깥 모니터에 직접 명령(라이브러리 없이 macOS 안의 IOAVService)
// 원리는 CLAUDE.md 「동작 원리」 참고. 시험용 명령줄은 Sources/ddc.swift
import Foundation
import IOKit
import CoreGraphics

// macOS 안에 있지만 공개 안 된 함수들
@_silgen_name("IOAVServiceCreateWithService")
private func IOAVServiceCreateWithService(_ a: CFAllocator?, _ s: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceReadI2C")
private func IOAVServiceReadI2C(_ s: CFTypeRef, _ chip: UInt32, _ off: UInt32, _ buf: UnsafeMutableRawPointer, _ n: UInt32) -> IOReturn
@_silgen_name("IOAVServiceWriteI2C")
private func IOAVServiceWriteI2C(_ s: CFTypeRef, _ chip: UInt32, _ off: UInt32, _ buf: UnsafeMutableRawPointer, _ n: UInt32) -> IOReturn
@_silgen_name("IOAVServiceCopyEDID")
private func IOAVServiceCopyEDID(_ s: CFTypeRef, _ out: UnsafeMutablePointer<Unmanaged<CFData>?>) -> IOReturn

enum VCP {
  static let input: UInt8 = 0x60
  static let brightness: UInt8 = 0x10
}

/// 바깥 모니터 하나. DDC 명령은 시간이 걸리니(수십~수백 ms) 메인 스레드 밖에서 부를 것
final class DDCMonitor: @unchecked Sendable {
  let name: String
  /// 모니터를 구분하는 값(EDID 제조사·모델·일련번호). 같은 모델 두 대도 구분됨
  let key: String
  /// macOS 화면(NSScreen)과 맞춰 볼 값 — CGDisplayVendorNumber·ModelNumber·SerialNumber와 같음
  let vendor: UInt32, model: UInt32, serial: UInt32
  private let av: CFTypeRef
  private let lock = NSLock()   // 한 모니터에 명령이 겹치지 않게

  private static let addr: UInt32 = 0x37, sub: UInt32 = 0x51, host: UInt8 = 0x51 ^ 0x6E   // 체크섬 시작값

  private init(av: CFTypeRef) {
    self.av = av
    var out: Unmanaged<CFData>?
    let edid = IOAVServiceCopyEDID(av, &out) == KERN_SUCCESS ? out?.takeRetainedValue() as Data? : nil
    self.name = edid.flatMap(Self.edidName) ?? "알 수 없는 모니터"
    self.key = edid.map { $0.count >= 16 ? $0[8..<16].map { String(format: "%02X", $0) }.joined() : "" } ?? ""
    if let d = edid, d.count >= 16 {
      vendor = UInt32(d[8]) << 8 | UInt32(d[9])
      model = UInt32(d[10]) | UInt32(d[11]) << 8
      serial = UInt32(d[12]) | UInt32(d[13]) << 8 | UInt32(d[14]) << 16 | UInt32(d[15]) << 24
    } else {
      vendor = 0; model = 0; serial = 0
    }
  }

  /// 이 모니터가 macOS 화면 id와 같은 모니터인지
  func matches(_ display: CGDirectDisplayID) -> Bool {
    vendor != 0 && CGDisplayVendorNumber(display) == vendor && CGDisplayModelNumber(display) == model
      && (serial == 0 || CGDisplaySerialNumber(display) == 0 || CGDisplaySerialNumber(display) == serial)
  }

  /// 연결된 바깥 모니터 전부(DDC 응답 여부와 상관없이)
  static func all() -> [DDCMonitor] {
    var it: io_iterator_t = 0, r: [DDCMonitor] = []
    guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &it) == KERN_SUCCESS else { return [] }
    defer { IOObjectRelease(it) }
    while case let s = IOIteratorNext(it), s != 0 {
      defer { IOObjectRelease(s) }
      let loc = IORegistryEntryCreateCFProperty(s, "Location" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
      guard loc == "External", let av = IOAVServiceCreateWithService(kCFAllocatorDefault, s)?.takeRetainedValue() else { continue }
      r.append(DDCMonitor(av: av))
    }
    return r
  }

  /// EDID에서 모니터 이름(0xFC 칸)
  private static func edidName(_ d: Data) -> String? {
    for o in stride(from: 54, to: min(126, d.count - 17), by: 18) where d[o] == 0 && d[o + 1] == 0 && d[o + 3] == 0xFC {
      let s = String(decoding: d[(o + 5)..<(o + 18)], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
      if !s.isEmpty { return s }
    }
    return nil
  }

  private func send(_ body: [UInt8]) -> Bool {
    var p = body; p.append(body.reduce(Self.host, ^))
    var ok = false
    for _ in 0..<2 {   // 두 번 보내야 받는 모니터가 있음
      usleep(10_000)
      ok = IOAVServiceWriteI2C(av, Self.addr, Self.sub, &p, UInt32(p.count)) == KERN_SUCCESS || ok
    }
    return ok
  }

  /// VCP 값 읽기 → (지금, 최대). 응답 없으면 nil
  func read(_ vcp: UInt8) -> (current: Int, max: Int)? {
    lock.lock(); defer { lock.unlock() }
    for _ in 0..<4 {
      guard send([0x82, 0x01, vcp]) else { continue }
      usleep(50_000)
      var b = [UInt8](repeating: 0, count: 11)
      guard IOAVServiceReadI2C(av, Self.addr, 0, &b, 11) == KERN_SUCCESS else { continue }
      if b[2] == 0x02, b[3] == 0, b[4] == vcp { return (Int(b[8]) << 8 | Int(b[9]), Int(b[6]) << 8 | Int(b[7])) }
    }
    return nil
  }

  @discardableResult
  func write(_ vcp: UInt8, _ value: Int) -> Bool {
    lock.lock(); defer { lock.unlock() }
    return send([0x84, 0x03, vcp, UInt8(value >> 8 & 0xFF), UInt8(value & 0xFF)])
  }

  /// 기능 목록(capabilities) 문자열. 명령 0xF3 + 오프셋을 32바이트씩 이어 읽음. 안 알려 주는 모니터는 nil
  func capabilities() -> String? {
    lock.lock(); defer { lock.unlock() }
    var s = [UInt8](), off = 0, fails = 0
    while fails < 5, s.count < 8192 {
      guard send([0x83, 0xF3, UInt8(off >> 8 & 0xFF), UInt8(off & 0xFF)]) else { fails += 1; continue }
      usleep(60_000)
      var b = [UInt8](repeating: 0, count: 38)
      guard IOAVServiceReadI2C(av, Self.addr, 0, &b, 38) == KERN_SUCCESS, b[2] == 0xE3,
            Int(b[3]) << 8 | Int(b[4]) == off else { fails += 1; continue }
      let len = Int(b[1] & 0x7F) - 3
      if len <= 0 { break }   // 끝
      s += b[5..<(5 + min(len, 32))]; off += len; fails = 0
    }
    let str = String(decoding: s.filter { $0 != 0 }, as: UTF8.self)
    return str.contains("vcp") ? str : nil
  }

  /// 기능 목록에서 입력 소스(VCP 0x60)가 받는 값들. 예: "vcp(... 60(11 12 0F) ...)" → [17, 18, 15]
  static func inputCodes(fromCapabilities caps: String) -> [Int]? {
    guard let start = caps.range(of: "vcp(") else { return nil }
    var depth = 0, token = "", capturing = false, inner = ""
    for ch in caps[start.upperBound...] {
      if capturing {
        if ch == ")" { break }
        inner.append(ch); continue
      }
      switch ch {
      case "(":
        if depth == 0, token.uppercased() == "60" { capturing = true }
        depth += 1; token = ""
      case ")":
        if depth == 0 { return nil }   // vcp( 끝까지 60이 없음
        depth -= 1; token = ""
      case " ":
        token = ""
      default:
        if depth == 0 { token.append(ch) }
      }
    }
    guard capturing else { return nil }
    let codes = inner.split(separator: " ").compactMap { Int($0, radix: 16) }
    return codes.isEmpty ? nil : codes
  }
}
