// DDC/CI — 애플 실리콘 맥에서 바깥 모니터에 직접 명령(라이브러리 없이 macOS 안의 IOAVService)
// 원리는 CLAUDE.md 「동작 원리」 참고. 시험용 명령줄은 Sources/ddc.swift
import Foundation
import IOKit

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
  private let av: CFTypeRef
  private let lock = NSLock()   // 한 모니터에 명령이 겹치지 않게

  private static let addr: UInt32 = 0x37, sub: UInt32 = 0x51, host: UInt8 = 0x51 ^ 0x6E   // 체크섬 시작값

  private init(av: CFTypeRef) {
    self.av = av
    self.name = Self.edidName(av)
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
  private static func edidName(_ av: CFTypeRef) -> String {
    var out: Unmanaged<CFData>?
    guard IOAVServiceCopyEDID(av, &out) == KERN_SUCCESS, let d = out?.takeRetainedValue() as Data? else { return "알 수 없는 모니터" }
    for o in stride(from: 54, to: min(126, d.count - 17), by: 18) where d[o] == 0 && d[o + 1] == 0 && d[o + 3] == 0xFC {
      let s = String(decoding: d[(o + 5)..<(o + 18)], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
      if !s.isEmpty { return s }
    }
    return "알 수 없는 모니터"
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
}
