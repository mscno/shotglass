import AppKit
import Foundation

let folder = URL(fileURLWithPath: CommandLine.arguments[1])
let iconset = folder.appendingPathComponent("AppIcon.iconset")
try FileManager.default.createDirectory(at: iconset,withIntermediateDirectories: true)
for size in [16,32,128,256,512] {
    for scale in [1,2] {
        let pixels = size*scale
        let rep = NSBitmapImageRep(bitmapDataPlanes: nil,pixelsWide: pixels,pixelsHigh: pixels,bitsPerSample: 8,samplesPerPixel: 4,hasAlpha: true,isPlanar: false,colorSpaceName: .deviceRGB,bytesPerRow: 0,bitsPerPixel: 0)!
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        let bounds = NSRect(x: 0,y: 0,width: pixels,height: pixels)
        let inset = CGFloat(pixels)*0.07
        let shape = NSBezierPath(roundedRect: bounds.insetBy(dx: inset,dy: inset),xRadius: CGFloat(pixels)*0.20,yRadius: CGFloat(pixels)*0.20)
        NSGradient(colors: [NSColor(srgbRed: 0.72,green: 0.59,blue: 1,alpha: 1),NSColor(srgbRed: 0.36,green: 0.24,blue: 0.71,alpha: 1)])!.draw(in: shape,angle: -75)
        NSColor.white.setStroke()
        let lo = CGFloat(pixels)*0.27; let hi = CGFloat(pixels)*0.73; let span = CGFloat(pixels)*0.14
        let line = NSBezierPath(); line.lineWidth = CGFloat(pixels)*0.04; line.lineCapStyle = .round; line.lineJoinStyle = .round
        for (x,y,dx,dy) in [(lo,lo,span,span),(hi,lo,-span,span),(lo,hi,span,-span),(hi,hi,-span,-span)] {
            line.move(to: NSPoint(x: x,y: y+dy)); line.line(to: NSPoint(x: x,y: y)); line.line(to: NSPoint(x: x+dx,y: y))
        }
        line.stroke()
        let dot = NSBezierPath(ovalIn: NSRect(x: CGFloat(pixels)*0.46,y: CGFloat(pixels)*0.46,width: CGFloat(pixels)*0.08,height: CGFloat(pixels)*0.08))
        NSColor.white.setFill(); dot.fill()
        NSGraphicsContext.current = nil
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try rep.representation(using: .png,properties: [:])!.write(to: iconset.appendingPathComponent(name))
    }
}
let process = Process(); process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c","icns",iconset.path,"-o",folder.appendingPathComponent("AppIcon.icns").path]
try process.run(); process.waitUntilExit()
if process.terminationStatus != 0 { exit(process.terminationStatus) }
