import Foundation
import CoreGraphics

/// Listen-only CGEventTap that reports one callback per physical key press,
/// including modifier keys (which arrive as flagsChanged, not keyDown).
final class KeyTap {
    /// Called on the tap's own thread with the virtual key code.
    var onKeyPress: ((Int) -> Void)?

    private var port: CFMachPort?
    private var runLoop: CFRunLoop?
    private var thread: Thread?
    private var heldModifiers = Set<Int64>()   // only touched on the tap thread

    var isRunning: Bool { port != nil }

    static var hasPermission: Bool { CGPreflightListenEventAccess() }
    static func requestPermission() { _ = CGRequestListenEventAccess() }

    /// Returns false when Input Monitoring permission has not been granted.
    @discardableResult
    func start() -> Bool {
        if port != nil { return true }
        let mask: CGEventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                          place: .headInsertEventTap,
                                          options: .listenOnly,
                                          eventsOfInterest: mask,
                                          callback: KeyTap.callback,
                                          userInfo: info) else {
            return false
        }
        port = tap
        let t = Thread { [weak self] in
            guard let self, let tap = self.port else { return }
            let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            let rl = CFRunLoopGetCurrent()
            self.runLoop = rl
            CFRunLoopAddSource(rl, source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            CFRunLoopRun()
        }
        t.name = "KeyHeat.EventTap"
        t.qualityOfService = .userInteractive
        t.start()
        thread = t
        return true
    }

    func stop() {
        guard let tap = port else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let rl = runLoop { CFRunLoopStop(rl) }
        CFMachPortInvalidate(tap)
        port = nil
        runLoop = nil
        thread = nil
    }

    func setEnabled(_ on: Bool) {
        if let tap = port { CGEvent.tapEnable(tap: tap, enable: on) }
    }

    private static let callback: CGEventTapCallBack = { _, type, event, userInfo in
        if let userInfo {
            let tap = Unmanaged<KeyTap>.fromOpaque(userInfo).takeUnretainedValue()
            tap.handle(type: type, event: event)
        }
        return Unmanaged.passUnretained(event)
    }

    private func handle(type: CGEventType, event: CGEvent) {
        switch type {
        case .keyDown:
            // A held key auto-repeats; that is one press, not many.
            guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }
            onKeyPress?(Int(event.getIntegerValueField(.keyboardEventKeycode)))
        case .flagsChanged:
            let code = event.getIntegerValueField(.keyboardEventKeycode)
            if isPress(code: code, flags: event.flags) { onKeyPress?(Int(code)) }
        case .tapDisabledByTimeout, .tapDisabledByUserInput:
            if let port { CGEvent.tapEnable(tap: port, enable: true) }
        default:
            break
        }
    }

    /// Device-specific modifier bits carried in CGEventFlags (NX_DEVICE*KEYMASK).
    /// These distinguish left from right, which the generic masks do not.
    private static let deviceMasks: [Int64: UInt64] = [
        0x3B: 0x0000_0001, // left control
        0x38: 0x0000_0002, // left shift
        0x3C: 0x0000_0004, // right shift
        0x37: 0x0000_0008, // left command
        0x36: 0x0000_0010, // right command
        0x3A: 0x0000_0020, // left option
        0x3D: 0x0000_0040, // right option
        0x3E: 0x0000_2000, // right control
        0x3F: 0x0080_0000, // fn (kCGEventFlagMaskSecondaryFn)
    ]

    /// flagsChanged fires on both press and release; decide which this is.
    private func isPress(code: Int64, flags: CGEventFlags) -> Bool {
        if code == 0x39 { return true } // caps lock: one event per tap
        if let mask = KeyTap.deviceMasks[code] {
            let down = (flags.rawValue & mask) != 0
            if down { heldModifiers.insert(code) } else { heldModifiers.remove(code) }
            return down
        }
        // Unknown modifier key: alternate press/release.
        if heldModifiers.contains(code) {
            heldModifiers.remove(code)
            return false
        }
        heldModifiers.insert(code)
        return true
    }
}
