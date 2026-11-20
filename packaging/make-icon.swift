// 앱 아이콘(T1: 모니터 두 대 + 전환 배지)을 그려 packaging/AppIcon.icns 를 만듦
//   swiftc -o /tmp/make-icon packaging/make-icon.swift -framework AppKit && /tmp/make-icon packaging
import AppKit

let c = { (r: CGFloat, g: CGFloat, b: CGFloat) in NSColor(srgbRed: r/255, green: g/255, blue: b/255, alpha: 1) }
var S: CGFloat = 1
func R(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> NSRect { NSRect(x: x * S, y: y * S, width: w * S, height: h * S) }

enum Fill { case split, blue, warm, glass }

func shadow(_ a: CGFloat, _ blur: CGFloat, _ dy: CGFloat, _ body: () -> Void) {
  NSGraphicsContext.saveGraphicsState()
  let sh = NSShadow(); sh.shadowColor = .black.withAlphaComponent(a); sh.shadowBlurRadius = blur * S; sh.shadowOffset = NSSize(width: 0, height: -dy * S); sh.set()
  body()
  NSGraphicsContext.restoreGraphicsState()
}

func background(_ top: NSColor, _ bottom: NSColor, angle: CGFloat = -90) {
  let base = NSBezierPath(roundedRect: R(100, 100, 824, 824), xRadius: 185.4 * S, yRadius: 185.4 * S)
  shadow(0.28, 20, 8) { top.setFill(); base.fill() }
  NSGradient(starting: top, ending: bottom)!.draw(in: base, angle: angle)
}

/// K2 받침(판 + 발)과 모니터. x,y = 모니터 왼쪽 아래, w,h = 모니터 크기, standH = 받침 높이
func monitor(x: CGFloat, y: CGFloat, w: CGFloat, h: CGFloat, standH: CGFloat, fill: Fill, arrows: Bool,
             bezel: NSColor = c(14, 14, 16), standColor: NSColor = c(200, 204, 210)) {
  let k = w / 684   // 크기 비율
  standColor.setFill()
  let mid = x + w / 2
  NSBezierPath(roundedRect: R(mid - 50 * k, y - standH + 18 * k, 100 * k, standH), xRadius: 6 * k * S, yRadius: 6 * k * S).fill()
  NSBezierPath(roundedRect: R(mid - 110 * k, y - standH, 220 * k, 26 * k), xRadius: 13 * k * S, yRadius: 13 * k * S).fill()

  let frame = R(x, y, w, h)
  if fill == .glass {
    shadow(0.25, 24, 8) { NSColor.white.withAlphaComponent(0.22).setFill(); NSBezierPath(roundedRect: frame, xRadius: 26 * k * S, yRadius: 26 * k * S).fill() }
    let e = NSBezierPath(roundedRect: frame.insetBy(dx: 2 * S, dy: 2 * S), xRadius: 25 * k * S, yRadius: 25 * k * S)
    e.lineWidth = 4 * S; NSColor.white.withAlphaComponent(0.6).setStroke(); e.stroke()
  } else {
    shadow(0.35, 18, 6) { bezel.setFill(); NSBezierPath(roundedRect: frame, xRadius: 22 * k * S, yRadius: 22 * k * S).fill() }
    let e = NSBezierPath(roundedRect: frame.insetBy(dx: 1.5 * S, dy: 1.5 * S), xRadius: 21 * k * S, yRadius: 21 * k * S)
    e.lineWidth = 3 * S; c(90, 92, 98).setStroke(); e.stroke()
  }
  let scr = frame.insetBy(dx: 18 * k * S, dy: 18 * k * S)
  NSGraphicsContext.saveGraphicsState(); NSBezierPath(roundedRect: scr, xRadius: 8 * k * S, yRadius: 8 * k * S).addClip()
  switch fill {
  case .split:
    NSGradient(starting: c(40, 150, 255), ending: c(20, 70, 210))!.draw(in: NSRect(x: scr.minX, y: scr.minY, width: scr.width / 2, height: scr.height), angle: -90)
    NSGradient(starting: c(255, 120, 70), ending: c(230, 40, 120))!.draw(in: NSRect(x: scr.midX, y: scr.minY, width: scr.width / 2, height: scr.height), angle: -90)
  case .blue: NSGradient(starting: c(60, 165, 255), ending: c(20, 70, 210))!.draw(in: scr, angle: -60)
  case .warm: NSGradient(starting: c(255, 140, 70), ending: c(230, 40, 120))!.draw(in: scr, angle: -60)
  case .glass: NSGradient(starting: NSColor.white.withAlphaComponent(0.35), ending: NSColor.white.withAlphaComponent(0.12))!.draw(in: scr, angle: -60)
  }
  NSGraphicsContext.restoreGraphicsState()
  if arrows { symbol("arrow.left.arrow.right", in: scr, size: 190 * k) }
}

func symbol(_ name: String, in r: NSRect, size: CGFloat, color: NSColor = .white, weight: NSFont.Weight = .bold) {
  let cfg = NSImage.SymbolConfiguration(pointSize: size * S, weight: weight).applying(.init(paletteColors: [color]))
  guard let img = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(cfg) else { return }
  shadow(0.3, 10, 0) { img.draw(in: NSRect(x: r.midX - img.size.width / 2, y: r.midY - img.size.height / 2, width: img.size.width, height: img.size.height)) }
}

func make(_ size: CGFloat = 1024, _ draw: @escaping () -> Void) -> NSImage {
  NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in S = size / 1024; draw(); return true }
}

let dark = (c(58, 60, 66), c(24, 25, 28))
func appIcon(_ size: CGFloat) -> NSImage {
  make(size) {
    background(dark.0, dark.1)
    monitor(x: 330, y: 470, w: 470, h: 300, standH: 120, fill: .warm, arrows: false)   // 뒤(주황) — 받침은 앞 모니터 뒤로 숨김
    monitor(x: 200, y: 330, w: 470, h: 300, standH: 110, fill: .blue, arrows: false)   // 앞(파랑)
    let badge = NSBezierPath(ovalIn: R(600, 250, 190, 190))
    shadow(0.35, 16, 6) { NSColor.white.setFill(); badge.fill() }
    symbol("arrow.left.arrow.right", in: R(600, 250, 190, 190), size: 96, color: c(30, 30, 34))
  }
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let set = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AppIcon.iconset")
try? FileManager.default.removeItem(at: set)
try! FileManager.default.createDirectory(at: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
  for scale in [1, 2] {
    let px = base * scale
    // 픽셀 크기 그대로 그리기(크기마다 다시 그려서 작은 아이콘도 또렷하게)
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8, samplesPerPixel: 4,
                               hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = NSSize(width: px, height: px)
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    appIcon(CGFloat(px)).draw(in: NSRect(x: 0, y: 0, width: px, height: px))
    NSGraphicsContext.restoreGraphicsState()
    let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
    try! rep.representation(using: .png, properties: [:])!.write(to: set.appendingPathComponent(name))
  }
}
let p = Process()
p.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
p.arguments = ["-c", "icns", set.path, "-o", "\(out)/AppIcon.icns"]
try! p.run(); p.waitUntilExit()
print(p.terminationStatus == 0 ? "만듦: \(out)/AppIcon.icns" : "iconutil 실패")
