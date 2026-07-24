import AppKit

// Renders the DMG installer background at 1x and 2x.
// Usage: swift dmg-background.swift <version> <out1x.png> <out2x.png>

guard CommandLine.arguments.count == 4 else {
  FileHandle.standardError.write(Data("usage: dmg-background.swift <version> <out1x.png> <out2x.png>\n".utf8))
  exit(1)
}
let version = CommandLine.arguments[1]

let size = NSSize(width: 660, height: 400)

func render(scale: CGFloat, to path: String) {
  let pixelsWide = Int(size.width * scale)
  let pixelsHigh = Int(size.height * scale)
  guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: pixelsWide, pixelsHigh: pixelsHigh,
    bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
    colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
  ) else { fatalError("could not create bitmap") }

  NSGraphicsContext.saveGraphicsState()
  let ctx = NSGraphicsContext(bitmapImageRep: rep)!
  NSGraphicsContext.current = ctx
  ctx.cgContext.scaleBy(x: scale, y: scale)

  // Soft vertical gradient, very light neutral.
  let gradient = NSGradient(
    starting: NSColor(calibratedRed: 0.965, green: 0.968, blue: 0.978, alpha: 1),
    ending: NSColor(calibratedRed: 0.988, green: 0.988, blue: 0.994, alpha: 1)
  )!
  gradient.draw(in: NSRect(origin: .zero, size: size), angle: 90)

  let center = size.width / 2

  let title = "ClipHub" as NSString
  let titleAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 27, weight: .semibold),
    .foregroundColor: NSColor(calibratedRed: 0.20, green: 0.22, blue: 0.27, alpha: 1)
  ]
  let titleSize = title.size(withAttributes: titleAttrs)
  title.draw(at: NSPoint(x: center - titleSize.width / 2, y: 320), withAttributes: titleAttrs)

  let subtitle = "Drag the icon to the Applications folder to install" as NSString
  let subAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.58, green: 0.61, blue: 0.66, alpha: 1)
  ]
  let subSize = subtitle.size(withAttributes: subAttrs)
  subtitle.draw(at: NSPoint(x: center - subSize.width / 2, y: 296), withAttributes: subAttrs)

  // Arrow between the two icon positions (icons sit at x=165 and x=495, centers ~y=185).
  let arrowColor = NSColor(calibratedRed: 0.69, green: 0.72, blue: 0.77, alpha: 1)
  arrowColor.setStroke()
  let arrowY: CGFloat = 185
  let shaft = NSBezierPath()
  shaft.lineWidth = 5
  shaft.lineCapStyle = .round
  shaft.move(to: NSPoint(x: 262, y: arrowY))
  shaft.line(to: NSPoint(x: 386, y: arrowY))
  shaft.stroke()
  let head = NSBezierPath()
  head.lineWidth = 5
  head.lineCapStyle = .round
  head.lineJoinStyle = .round
  head.move(to: NSPoint(x: 370, y: arrowY + 14))
  head.line(to: NSPoint(x: 392, y: arrowY))
  head.line(to: NSPoint(x: 370, y: arrowY - 14))
  head.stroke()

  let versionText = "Version \(version)" as NSString
  let verAttrs: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 10.5, weight: .regular),
    .foregroundColor: NSColor(calibratedRed: 0.72, green: 0.75, blue: 0.79, alpha: 1)
  ]
  let verSize = versionText.size(withAttributes: verAttrs)
  versionText.draw(at: NSPoint(x: center - verSize.width / 2, y: 18), withAttributes: verAttrs)

  NSGraphicsContext.restoreGraphicsState()

  guard let png = rep.representation(using: .png, properties: [:]) else { fatalError("png encode failed") }
  try! png.write(to: URL(fileURLWithPath: path))
}

render(scale: 1, to: CommandLine.arguments[2])
render(scale: 2, to: CommandLine.arguments[3])
