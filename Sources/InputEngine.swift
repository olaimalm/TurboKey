import ApplicationServices
import Cocoa

/// Captures keyboard and mouse events globally (CGEventTap) and sends extra presses.
/// All state here is only changed on the main thread; sending happens on separate queues.
final class InputEngine {
    /// Tags events we sent ourselves, so we never multiply our own presses.
    static let marker: Int64 = 0x5455_5242
    /// ⌃⌥⌘M turns TurboKey on and off.
    static let toggleKeyCode: UInt16 = 46

    var onToggleHotkey: (() -> Void)?

    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var mappings: [Trigger: Mapping] = [:]
    private var active = false
    private var holdTimers: [Trigger: DispatchSourceTimer] = [:]

    private let burstQueue = DispatchQueue(label: "TurboKey.burst")
    private let holdQueue = DispatchQueue(label: "TurboKey.hold")
    private let source: CGEventSource? = {
        let source = CGEventSource(stateID: .privateState)
        source?.localEventsSuppressionInterval = 0
        return source
    }()

    private let lock = NSLock()
    private var generation = 0

    var isRunning: Bool { tap != nil }

    // MARK: - Setup

    func configure(mappings list: [Mapping], active: Bool) {
        var dict: [Trigger: Mapping] = [:]
        for mapping in list where mapping.enabled {
            if let trigger = mapping.trigger, dict[trigger] == nil { dict[trigger] = mapping }
        }
        mappings = dict
        self.active = active

        for trigger in Array(holdTimers.keys) where !active || dict[trigger]?.mode != .hold {
            stopHold(trigger, release: false)
        }
        if !active { cancelBursts() }
    }

    @discardableResult
    func start() -> Bool {
        if tap != nil { return true }
        let types: [CGEventType] = [.keyDown, .keyUp, .leftMouseDown, .leftMouseUp, .rightMouseDown, .rightMouseUp]
        let mask = types.reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: tapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else { return false }

        self.tap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        for trigger in Array(holdTimers.keys) { stopHold(trigger, release: false) }
        cancelBursts()
        if let tap { CGEvent.tapEnable(tap: tap, enable: false) }
        if let runLoopSource { CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes) }
        tap = nil
        runLoopSource = nil
    }

    // MARK: - Events

    fileprivate func handle(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let pass = Unmanaged.passUnretained(event)

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return pass
        }
        if event.getIntegerValueField(.eventSourceUserData) == Self.marker { return pass }

        let flags = event.flags
        // Shortcuts like ⌘W or ⌃C are never multiplied.
        let blocked = !flags.intersection([.maskCommand, .maskControl, .maskAlternate]).isEmpty

        switch type {
        case .keyDown:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            let isRepeat = event.getIntegerValueField(.keyboardEventAutorepeat) != 0

            if code == Self.toggleKeyCode, flags.contains([.maskCommand, .maskControl, .maskAlternate]) {
                if !isRepeat { DispatchQueue.main.async { [weak self] in self?.onToggleHotkey?() } }
                return nil
            }

            let trigger = Trigger(kind: .key, keyCode: code)
            if holdTimers[trigger] != nil { return nil } // swallow the OS key repeat
            guard active, !blocked, let mapping = mappings[trigger] else { return pass }

            switch mapping.mode {
            case .multiply:
                if !isRepeat { burst(trigger, count: mapping.count - 1, delayMs: mapping.delayMs, flags: flags) }
                return pass
            case .hold:
                if isRepeat { return nil }
                startHold(trigger, intervalMs: mapping.delayMs, flags: flags)
                return pass
            }

        case .keyUp:
            let code = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
            return stopHold(Trigger(kind: .key, keyCode: code), release: true) ? nil : pass

        case .leftMouseDown, .rightMouseDown:
            let trigger = Trigger(kind: type == .leftMouseDown ? .mouseLeft : .mouseRight)
            guard active, !blocked, let mapping = mappings[trigger], mapping.mode == .hold else { return pass }
            startHold(trigger, intervalMs: mapping.delayMs, flags: [])
            return pass

        case .leftMouseUp, .rightMouseUp:
            let trigger = Trigger(kind: type == .leftMouseUp ? .mouseLeft : .mouseRight)
            if stopHold(trigger, release: true) { return nil }
            guard active, !blocked, let mapping = mappings[trigger], mapping.mode == .multiply else { return pass }
            burst(trigger, count: mapping.count - 1, delayMs: mapping.delayMs, flags: [])
            return pass

        default:
            return pass
        }
    }

    // MARK: - Multiply

    private func burst(_ trigger: Trigger, count: Int, delayMs: Int, flags: CGEventFlags) {
        guard count > 0 else { return }
        let gen = currentGeneration()
        burstQueue.async { [weak self] in
            for _ in 0..<count {
                usleep(useconds_t(max(delayMs, 1) * 1000))
                guard let self, gen == self.currentGeneration() else { return }
                self.post(trigger, down: true, flags: flags)
                self.post(trigger, down: false, flags: flags)
            }
        }
    }

    private func currentGeneration() -> Int {
        lock.lock(); defer { lock.unlock() }
        return generation
    }

    private func cancelBursts() {
        lock.lock(); generation += 1; lock.unlock()
    }

    // MARK: - Hold to spam

    private func startHold(_ trigger: Trigger, intervalMs: Int, flags: CGEventFlags) {
        let interval = DispatchTimeInterval.milliseconds(max(intervalMs, 5))
        let timer = DispatchSource.makeTimerSource(queue: holdQueue)
        timer.schedule(deadline: .now() + interval, repeating: interval)
        timer.setEventHandler { [weak self] in
            // Release and press again, so the key is still down when you let go yourself.
            self?.post(trigger, down: false, flags: flags)
            self?.post(trigger, down: true, flags: flags)
        }
        holdTimers[trigger] = timer
        timer.resume()
    }

    /// Stops an active hold. With `release`, the release event is sent after the last tick,
    /// so the key/button never gets stuck down.
    @discardableResult
    private func stopHold(_ trigger: Trigger, release: Bool) -> Bool {
        guard let timer = holdTimers.removeValue(forKey: trigger) else { return false }
        timer.cancel()
        if release {
            holdQueue.async { [weak self] in self?.post(trigger, down: false, flags: []) }
        }
        return true
    }

    // MARK: - Sending

    private func post(_ trigger: Trigger, down: Bool, flags: CGEventFlags) {
        let event: CGEvent?
        switch trigger.kind {
        case .key:
            event = CGEvent(keyboardEventSource: source, virtualKey: CGKeyCode(trigger.keyCode), keyDown: down)
            event?.flags = flags
        case .mouseLeft, .mouseRight:
            let left = trigger.kind == .mouseLeft
            let type: CGEventType = left
                ? (down ? .leftMouseDown : .leftMouseUp)
                : (down ? .rightMouseDown : .rightMouseUp)
            let location = CGEvent(source: nil)?.location ?? .zero
            event = CGEvent(mouseEventSource: source, mouseType: type, mouseCursorPosition: location,
                            mouseButton: left ? .left : .right)
            event?.setIntegerValueField(.mouseEventClickState, value: 1)
        }
        guard let event else { return }
        event.setIntegerValueField(.eventSourceUserData, value: Self.marker)
        event.post(tap: .cghidEventTap)
    }
}

private let tapCallback: CGEventTapCallBack = { _, type, event, refcon in
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let engine = Unmanaged<InputEngine>.fromOpaque(refcon).takeUnretainedValue()
    return engine.handle(type: type, event: event)
}
