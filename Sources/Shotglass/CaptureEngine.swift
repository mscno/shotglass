import AppKit
import ScreenCaptureKit
import Vision
import ShotglassCore

enum CaptureTarget {
    case display(CGDirectDisplayID)
    case region(CGRect)
    case window(SCWindow)
}

@MainActor final class CaptureEngine {
    var content: SCShareableContent?
    var windows: [SCWindow] = [] { didSet { windowLookup = Dictionary(windows.map { ($0.windowID,$0) },uniquingKeysWith: { first,_ in first }) } }
    private var windowLookup: [CGWindowID: SCWindow] = [:]
    var previousApp: NSRunningApplication?
    var permission: Bool { CGPreflightScreenCaptureAccess() }

    func refresh() async throws {
        content = try await SCShareableContent.excludingDesktopWindows(false,onScreenWindowsOnly: true)
        guard content?.displays.isEmpty == false else { throw ShotError.message("No screens are available to capture. Wake and unlock your Mac, then try again. If this continues, check Shotglass's Screen Recording access in System Settings.") }
        let ownPID = ProcessInfo.processInfo.processIdentifier
        let candidates = content?.windows.filter {
            $0.owningApplication?.processID != ownPID && $0.owningApplication?.bundleIdentifier != Bundle.main.bundleIdentifier && $0.windowLayer == 0 && $0.frame.width > 40 && $0.frame.height > 40 && $0.isOnScreen
        } ?? []
        // ScreenCaptureKit doesn't promise front-to-back ordering. Quartz does.
        let ordered = (CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String: Any]] ?? []).compactMap { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value }
        let ranks = Dictionary(ordered.enumerated().map { ($0.element,$0.offset) },uniquingKeysWith: min)
        windows = candidates.sorted { (ranks[$0.windowID] ?? Int.max) < (ranks[$1.windowID] ?? Int.max) }
    }
    func activeWindow() -> SCWindow? {
        let pid = previousApp?.processIdentifier ?? NSWorkspace.shared.frontmostApplication?.processIdentifier
        if let pid,pid != ProcessInfo.processInfo.processIdentifier,previousApp?.bundleIdentifier != Bundle.main.bundleIdentifier { return windows.first { $0.owningApplication?.processID == pid } }
        return windows.first
    }
    private var windowInfoTime = -Double.infinity
    private var cachedWindowInfo: [[String: Any]] = []
    private var liveWindowInfo: [[String: Any]] {
        let now = ProcessInfo.processInfo.systemUptime
        // High-rate mouse input needs at most one WindowServer query per display frame.
        if now-windowInfoTime >= 1.0/60.0 {
            cachedWindowInfo = CGWindowListCopyWindowInfo([.optionOnScreenOnly,.excludeDesktopElements],kCGNullWindowID) as? [[String: Any]] ?? []
            windowInfoTime = now
        }
        return cachedWindowInfo
    }
    private func quartzFrame(_ info: [String: Any]) -> CGRect? {
        guard let bounds = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: bounds)
    }
    func currentFrame(of window: SCWindow) -> CGRect {
        let info = liveWindowInfo.first { ($0[kCGWindowNumber as String] as? NSNumber)?.uint32Value == window.windowID }
        return CaptureGeometry.quartz(info.flatMap(quartzFrame) ?? window.frame,primaryHeight: NSScreen.primaryHeight)
    }
    func windowHit(at cocoa: CGPoint) -> (window: SCWindow,frame: CGRect)? {
        let point = CGPoint(x: cocoa.x,y: NSScreen.primaryHeight-cocoa.y)
        for info in liveWindowInfo {
            guard let id = (info[kCGWindowNumber as String] as? NSNumber)?.uint32Value,
                  let window = windowLookup[id],let frame = quartzFrame(info),frame.contains(point) else { continue }
            return (window,CaptureGeometry.quartz(frame,primaryHeight: NSScreen.primaryHeight))
        }
        return nil
    }
    func window(at cocoa: CGPoint) -> SCWindow? { windowHit(at: cocoa)?.window }
    func configuration(for target: CaptureTarget,recording: Bool = false) throws -> (SCContentFilter,SCStreamConfiguration) {
        guard let content else { throw ShotError.message("Screen capture is not ready. Try again.") }
        let p = Preferences.shared
        func pixelSize(_ n: Int) -> Int { recording ? even(n) : max(1,n) }
        let config = SCStreamConfiguration()
        config.showsCursor = recording ? p.recordCursor : p.captureCursor
        config.captureResolution = .best
        config.ignoreShadowsSingleWindow = !p.windowShadow || recording
        config.ignoreShadowsDisplay = true
        config.backgroundColor = CGColor.clear
        config.minimumFrameInterval = CMTime(value: 1,timescale: CMTimeScale(recording ? p.fps : 60))
        let filter: SCContentFilter
        switch target {
        case .window(let window):
            filter = SCContentFilter(desktopIndependentWindow: window)
            let scale = filter.pointPixelScale
            config.width = pixelSize(Int(filter.contentRect.width * CGFloat(scale)))
            config.height = pixelSize(Int(filter.contentRect.height * CGFloat(scale)))
        case .display(let id):
            guard let display = content.displays.first(where: { $0.displayID == id }) else { throw ShotError.message("This display is no longer connected.") }
            filter = displayFilter(display,content: content)
            let scale = CGFloat(filter.pointPixelScale)
            config.width = pixelSize(Int(display.frame.width*scale)); config.height = pixelSize(Int(display.frame.height*scale))
        case .region(let cocoaRect):
            let quartz = CaptureGeometry.quartz(cocoaRect,primaryHeight: NSScreen.primaryHeight)
            guard let display = content.displays.max(by: { area($0.frame.intersection(quartz)) < area($1.frame.intersection(quartz)) }),area(display.frame.intersection(quartz)) > 0 else { throw ShotError.message("The saved area is off screen. Draw a new area.") }
            filter = displayFilter(display,content: content)
            config.sourceRect = CaptureGeometry.sourceRect(quartz,in: display.frame)
            let scale = CGFloat(filter.pointPixelScale)
            config.width = pixelSize(Int(config.sourceRect.width*scale)); config.height = pixelSize(Int(config.sourceRect.height*scale))
        }
        return (filter,config)
    }
    private func even(_ n: Int) -> Int { max(2,n-n%2) }
    private func area(_ rect: CGRect) -> CGFloat { rect.isNull ? 0 : rect.width*rect.height }
    private func displayFilter(_ display: SCDisplay,content: SCShareableContent) -> SCContentFilter {
        var excluded = content.applications.filter { $0.bundleIdentifier == Bundle.main.bundleIdentifier || $0.processID == ProcessInfo.processInfo.processIdentifier }
        var exceptions: [SCWindow] = []
        if Preferences.shared.hideDesktopIcons {
            excluded += content.applications.filter { $0.bundleIdentifier == "com.apple.finder" }
            exceptions = content.windows.filter { $0.owningApplication?.bundleIdentifier == "com.apple.finder" && $0.windowLayer >= 0 }
        }
        return SCContentFilter(display: display,excludingApplications: excluded,exceptingWindows: exceptions)
    }
    func image(_ target: CaptureTarget) async throws -> CGImage {
        // Handle regions spanning monitors, including displays with different scale factors.
        if case .region(let rect) = target, let content {
            let quartz = CaptureGeometry.quartz(rect,primaryHeight: NSScreen.primaryHeight)
            let displays = content.displays.filter { !$0.frame.intersection(quartz).isNull && $0.frame.intersection(quartz).width > 0 }
            if displays.count > 1 {
                let scale = NSScreen.screens.map(\.backingScaleFactor).max() ?? 2
                guard let context = CGContext(data: nil,width: Int(rect.width*scale),height: Int(rect.height*scale),bitsPerComponent: 8,bytesPerRow: 0,space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { throw ShotError.message("Cannot create screenshot.") }
                for display in displays {
                    let intersection = quartz.intersection(display.frame)
                    let cocoa = CaptureGeometry.quartz(intersection,primaryHeight: NSScreen.primaryHeight)
                    let (filter,config) = try configuration(for: .region(cocoa))
                    let part = try await SCScreenshotManager.captureImage(contentFilter: filter,configuration: config)
                    context.draw(part,in: CGRect(x: (cocoa.minX-rect.minX)*scale,y: (cocoa.minY-rect.minY)*scale,width: cocoa.width*scale,height: cocoa.height*scale))
                }
                guard let result = context.makeImage() else { throw ShotError.message("Cannot combine displays.") }
                return result
            }
        }
        let (filter,config) = try configuration(for: target)
        return try await SCScreenshotManager.captureImage(contentFilter: filter,configuration: config)
    }
    nonisolated static func recognize(_ image: CGImage) async throws -> String {
        try await Task.detached(priority: .userInitiated) {
            let text = VNRecognizeTextRequest()
            text.recognitionLevel = .accurate
            text.usesLanguageCorrection = true
            text.automaticallyDetectsLanguage = true
            let codes = VNDetectBarcodesRequest()
            try VNImageRequestHandler(cgImage: image,options: [:]).perform([text,codes])
            let lines = text.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
            let qr = codes.results?.compactMap(\.payloadStringValue) ?? []
            return (lines+qr).joined(separator: "\n")
        }.value
    }
}
