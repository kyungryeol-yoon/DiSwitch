// DDC/CI 시험 — 애플 실리콘 맥에서 바깥 모니터에 직접 명령(라이브러리 없이 macOS 안의 IOAVService)
// 쓰는 법:  ddc list                 모니터 이름 · 지금 입력 번호(읽기만)
//           ddc set <n> <입력> [초]   n번 모니터 입력을 바꿈, [초] 주면 그만큼 뒤 원래 입력으로 되돌림
import Foundation
import IOKit

// macOS 안에 있지만 공개 안 된 함수들(m1ddc·MonitorControl도 같은 것)
@_silgen_name("IOAVServiceCreateWithService")
func IOAVServiceCreateWithService(_ a: CFAllocator?, _ s: io_service_t) -> Unmanaged<CFTypeRef>?
@_silgen_name("IOAVServiceReadI2C")
func IOAVServiceReadI2C(_ s: CFTypeRef, _ chip: UInt32, _ off: UInt32, _ buf: UnsafeMutableRawPointer, _ n: UInt32) -> IOReturn
@_silgen_name("IOAVServiceWriteI2C")
func IOAVServiceWriteI2C(_ s: CFTypeRef, _ chip: UInt32, _ off: UInt32, _ buf: UnsafeMutableRawPointer, _ n: UInt32) -> IOReturn
@_silgen_name("IOAVServiceCopyEDID")
func IOAVServiceCopyEDID(_ s: CFTypeRef, _ out: UnsafeMutablePointer<Unmanaged<CFData>?>) -> IOReturn

let DDC_ADDR: UInt32 = 0x37, DDC_SUB: UInt32 = 0x51, HOST: UInt8 = 0x51 ^ 0x6E   // 체크섬 시작값

struct Monitor { let av: CFTypeRef; let name: String }

// EDID에서 모니터 이름(0xFC 칸)
func edidName(_ av: CFTypeRef) -> String {
  var out: Unmanaged<CFData>?
  guard IOAVServiceCopyEDID(av, &out) == KERN_SUCCESS, let d = out?.takeRetainedValue() as Data? else { return "?" }
  for o in stride(from: 54, to: min(126, d.count - 17), by: 18) where d[o] == 0 && d[o + 1] == 0 && d[o + 3] == 0xFC {
    return String(decoding: d[(o + 5)..<(o + 18)], as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
  }
  return "?"
}

func monitors() -> [Monitor] {
  var it: io_iterator_t = 0, r: [Monitor] = []
  IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("DCPAVServiceProxy"), &it)
  while case let s = IOIteratorNext(it), s != 0 {
    defer { IOObjectRelease(s) }
    let loc = IORegistryEntryCreateCFProperty(s, "Location" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
    guard loc == "External", let av = IOAVServiceCreateWithService(kCFAllocatorDefault, s)?.takeRetainedValue() else { continue }
    r.append(Monitor(av: av, name: edidName(av)))
  }
  IOObjectRelease(it)
  return r
}

func send(_ av: CFTypeRef, _ body: [UInt8]) -> Bool {
  var p = body; p.append(body.reduce(HOST, ^))
  var ok = false
  for _ in 0..<2 { usleep(10_000); ok = IOAVServiceWriteI2C(av, DDC_ADDR, DDC_SUB, &p, UInt32(p.count)) == KERN_SUCCESS || ok }   // 두 번 보내야 받는 모니터가 있음
  return ok
}

// VCP 값 읽기 → (지금, 최대)
func get(_ av: CFTypeRef, _ vcp: UInt8) -> (Int, Int)? {
  for _ in 0..<4 {
    guard send(av, [0x82, 0x01, vcp]) else { continue }
    usleep(50_000)
    var b = [UInt8](repeating: 0, count: 11)
    guard IOAVServiceReadI2C(av, DDC_ADDR, 0, &b, 11) == KERN_SUCCESS else { continue }
    if b[2] == 0x02, b[3] == 0, b[4] == vcp { return (Int(b[8]) << 8 | Int(b[9]), Int(b[6]) << 8 | Int(b[7])) }
  }
  return nil
}

func set(_ av: CFTypeRef, _ vcp: UInt8, _ v: Int) -> Bool { send(av, [0x84, 0x03, vcp, UInt8(v >> 8 & 0xFF), UInt8(v & 0xFF)]) }

let a = CommandLine.arguments, ms = monitors()
if a.count < 2 || a[1] == "list" {
  if ms.isEmpty { print("바깥 모니터(DCPAVServiceProxy External) 없음") }
  for (i, m) in ms.enumerated() {
    let inp = get(m.av, 0x60), br = get(m.av, 0x10)
    print("\(i + 1). \(m.name) · 입력 \(inp.map { "\($0.0) (0x\(String($0.0, radix: 16)))" } ?? "못 읽음") · 밝기 \(br.map { "\($0.0)/\($0.1)" } ?? "못 읽음")")
  }
} else if a[1] == "set", a.count >= 4, let n = Int(a[2]), n >= 1, n <= ms.count, let v = Int(a[3]) {
  let m = ms[n - 1], before = get(m.av, 0x60)?.0
  print("\(m.name): 입력 \(before.map(String.init) ?? "?") → \(v) 보냄: \(set(m.av, 0x60, v) ? "성공" : "실패")")
  if a.count >= 5, let sec = Double(a[4]), let b = before {
    Thread.sleep(forTimeInterval: sec)
    print("\(sec)초 뒤 → \(b) 되돌림: \(set(m.av, 0x60, b) ? "성공" : "실패")")
  }
} else { print("ddc list | ddc set <n> <입력> [되돌릴 초]") }
