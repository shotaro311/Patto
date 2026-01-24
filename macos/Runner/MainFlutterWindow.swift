import Cocoa
import ApplicationServices
import FlutterMacOS

class MainFlutterWindow: NSWindow, NSWindowDelegate {
  private var quickLaunchMonitor: QuickLaunchMonitor?

  override func awakeFromNib() {
    let flutterViewController = FlutterViewController()
    let windowFrame = self.frame
    self.contentViewController = flutterViewController
    self.setFrame(windowFrame, display: true)
    self.delegate = self
    // アクティブなスペースにウィンドウを移動（Quick Launch用）
    // 注意: .moveToActiveSpace と .canJoinAllSpaces は排他的なので両方設定できない
    self.collectionBehavior.insert(.moveToActiveSpace)

    RegisterGeneratedPlugins(registry: flutterViewController)

    let channel = FlutterMethodChannel(
      name: "com.patto/quick_launch",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    let monitor = QuickLaunchMonitor(channel: channel, window: self)
    quickLaunchMonitor = monitor

    let aiChannel = FlutterMethodChannel(
      name: "com.patto/apple_intelligence",
      binaryMessenger: flutterViewController.engine.binaryMessenger
    )
    let aiBridge = AppleIntelligenceBridge()

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "configure":
        let args = call.arguments as? [String: Any]
        monitor.configure(
          modifierKeyRaw: args?["modifierKey"] as? String,
          showHideKeyBindingRaw: args?["showHideKeyBinding"]
        )
        result(nil)
      case "start":
        monitor.start()
        result(nil)
      case "stop":
        monitor.stop()
        result(nil)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    aiChannel.setMethodCallHandler { call, result in
      aiBridge.handle(call, result: result)
    }

    super.awakeFromNib()
  }

  func windowShouldClose(_ sender: NSWindow) -> Bool {
    NSApp.hide(nil)
    return false
  }
}

final class QuickLaunchMonitor {
  private let channel: FlutterMethodChannel
  private weak var window: NSWindow?

  private var showHideModifierKey: ModifierKey = .command
  private var showHideKeyBinding: KeyBinding?
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var globalMonitor: Any?
  private var localMonitor: Any?

  private var lastTriggerAt: TimeInterval = 0
  private var lastKeyEventAt: TimeInterval = 0
  private var lastKeyEventCode: UInt16 = 0
  private var showHideTapState = TapState()

  init(channel: FlutterMethodChannel, window: NSWindow) {
    self.channel = channel
    self.window = window
  }

  func configure(
    modifierKeyRaw: String?,
    showHideKeyBindingRaw: Any?
  ) {
    showHideModifierKey = ModifierKey(rawValue: modifierKeyRaw ?? "") ?? .command
    showHideKeyBinding = KeyBinding.fromMap(showHideKeyBindingRaw)
    resetTapStates()
  }

  func start() {
    stop()

    if #available(macOS 10.15, *) {
      if !CGPreflightListenEventAccess() {
        CGRequestListenEventAccess()
      }
    }

    localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
      self?.handle(event: event, isGlobal: false)
      return event
    }
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
      self?.handle(event: event, isGlobal: true)
    }

    _ = startEventTap()
  }

  func stop() {
    if let runLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    if let eventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
    }
    eventTap = nil
    runLoopSource = nil

    if let globalMonitor {
      NSEvent.removeMonitor(globalMonitor)
    }
    if let localMonitor {
      NSEvent.removeMonitor(localMonitor)
    }
    globalMonitor = nil
    localMonitor = nil
    resetTapStates()
  }

  private func startEventTap() -> Bool {
    let mask = CGEventMask(
      (1 << CGEventType.flagsChanged.rawValue) |
      (1 << CGEventType.keyDown.rawValue)
    )
    let userInfo = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    guard
      let tap = CGEvent.tapCreate(
        tap: .cgSessionEventTap,
        place: .headInsertEventTap,
        options: .listenOnly,
        eventsOfInterest: mask,
        callback: Self.eventTapCallback,
        userInfo: userInfo
      )
    else {
      return false
    }

    eventTap = tap
    runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    if let runLoopSource {
      CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
    }
    CGEvent.tapEnable(tap: tap, enable: true)
    return true
  }

  private static let eventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let monitor = Unmanaged<QuickLaunchMonitor>.fromOpaque(userInfo).takeUnretainedValue()
    monitor.handleEventTap(type: type, event: event)
    return Unmanaged.passUnretained(event)
  }

  private func handleEventTap(type: CGEventType, event: CGEvent) {
    // アプリが「前面かつ表示中」のときは、localMonitor側で拾えるのでeventTap側は無視して二重発火を防ぐ
    // ※非表示（NSApp.isHidden）の場合は、アクティブ扱いになるケースがあるため、isHiddenも併せて判定する
    guard !(NSApp.isActive && !NSApp.isHidden) else { return }
    switch type {
    case .flagsChanged:
      handleModifierEventTap(event)
      return
    case .keyDown:
      handleKeyDownEventTap(event)
      return
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
      if let eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      return
    default:
      return
    }
  }

  private func handle(event: NSEvent, isGlobal: Bool) {
    // 前面かつ表示中のときはlocalMonitorで十分なので、globalMonitorは無視して二重発火を防ぐ
    if isGlobal && NSApp.isActive && !NSApp.isHidden {
      return
    }
    switch event.type {
    case .flagsChanged:
      handleModifierEvent(event)
    case .keyDown:
      handleKeyDownEvent(event)
    default:
      break
    }
  }

  private func handleModifierEvent(_ event: NSEvent) {
    handleModifierKeyDown(
      keyCode: event.keyCode,
      isDown: { key in key.isDown(event.modifierFlags) }
    )
  }

  private func handleModifierEventTap(_ event: CGEvent) {
    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    handleModifierKeyDown(
      keyCode: keyCode,
      isDown: { key in key.isDown(event.flags) }
    )
  }

  private func handleKeyDownEvent(_ event: NSEvent) {
    handleKeyBinding(
      keyCode: event.keyCode,
      command: event.modifierFlags.contains(.command),
      control: event.modifierFlags.contains(.control),
      option: event.modifierFlags.contains(.option),
      shift: event.modifierFlags.contains(.shift)
    )
  }

  private func handleKeyDownEventTap(_ event: CGEvent) {
    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    let flags = event.flags
    handleKeyBinding(
      keyCode: keyCode,
      command: flags.contains(.maskCommand),
      control: flags.contains(.maskControl),
      option: flags.contains(.maskAlternate),
      shift: flags.contains(.maskShift)
    )
  }

  private func handleModifierKeyDown(
    keyCode: UInt16,
    isDown: (ModifierKey) -> Bool
  ) {
    if showHideModifierKey.keyCodes.contains(keyCode),
       isDown(showHideModifierKey) {
      if isDuplicateKeyEvent(keyCode) { return }
      if detectDoubleTap(state: &showHideTapState) {
        triggerShowHide()
      }
    }
  }

  private func handleKeyBinding(
    keyCode: UInt16,
    command: Bool,
    control: Bool,
    option: Bool,
    shift: Bool
  ) {
    let matchesShowHide = showHideKeyBinding?.matches(
      keyCode: keyCode,
      command: command,
      control: control,
      option: option,
      shift: shift
    ) ?? false
    guard matchesShowHide else { return }
    if isDuplicateKeyEvent(keyCode) { return }
    triggerShowHide()
  }

  private func detectDoubleTap(state: inout TapState) -> Bool {
    let now = ProcessInfo.processInfo.systemUptime
    if now - state.lastTapAt <= 0.35 {
      state.tapCount += 1
    } else {
      state.tapCount = 1
    }
    state.lastTapAt = now
    if state.tapCount >= 2 {
      state.tapCount = 0
      return true
    }
    return false
  }

  private func triggerShowHide() {
    guard canTriggerNow() else { return }
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      let window = activeWindow()
      if shouldHide(window: window) {
        NSApp.hide(nil)
        self.channel.invokeMethod("onQuickLaunch", arguments: [
          "source": "macos",
          "action": "hide",
        ])
        return
      }

      showApp(window: window)
      self.channel.invokeMethod("onQuickLaunch", arguments: [
        "source": "macos",
        "action": "show",
      ])
    }
  }

  private func canTriggerNow() -> Bool {
    let now = ProcessInfo.processInfo.systemUptime
    if now - lastTriggerAt <= 0.05 {
      return false
    }
    lastTriggerAt = now
    return true
  }

  private func resetTapStates() {
    lastTriggerAt = 0
    lastKeyEventAt = 0
    lastKeyEventCode = 0
    showHideTapState = TapState()
  }

  private func isDuplicateKeyEvent(_ keyCode: UInt16) -> Bool {
    let now = ProcessInfo.processInfo.systemUptime
    if keyCode == lastKeyEventCode && now - lastKeyEventAt <= 0.03 {
      return true
    }
    lastKeyEventCode = keyCode
    lastKeyEventAt = now
    return false
  }

  private func activeWindow() -> NSWindow? {
    return window
      ?? NSApp.keyWindow
      ?? NSApp.mainWindow
      ?? NSApp.windows.first(where: { $0.isVisible })
      ?? NSApp.windows.first
  }

  private func shouldHide(window: NSWindow? = nil) -> Bool {
    let targetWindow = window ?? activeWindow()
    return NSApp.isActive
      && !NSApp.isHidden
      && targetWindow?.isKeyWindow == true
      && targetWindow?.isVisible == true
      && targetWindow?.isMiniaturized == false
  }

  private func showApp(window: NSWindow?) {
    // アプリを通常のアクティベーションポリシーに設定（メニューバーアプリなどでない場合に必要）
    NSApp.setActivationPolicy(.regular)

    NSApp.unhide(nil)
    if let window, window.isMiniaturized {
      window.deminiaturize(nil)
    }

    // アプリをアクティベート
    NSRunningApplication.current.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
    NSApp.activate(ignoringOtherApps: true)

    // ウィンドウを前面に
    window?.makeKeyAndOrderFront(nil)
    window?.orderFrontRegardless()

    // 少し遅延を入れて再度前面に持ってくる（macOSのウィンドウマネージャーとの競合対策）
    if let window {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
      }
    }
  }


  private enum ModifierKey: String {
    case command
    case control
    case option
    case shift

    var keyCodes: Set<UInt16> {
      switch self {
      case .command:
        return [54, 55]
      case .control:
        return [59, 62]
      case .option:
        return [58, 61]
      case .shift:
        return [56, 60]
      }
    }

    func isDown(_ flags: NSEvent.ModifierFlags) -> Bool {
      switch self {
      case .command:
        return flags.contains(.command)
      case .control:
        return flags.contains(.control)
      case .option:
        return flags.contains(.option)
      case .shift:
        return flags.contains(.shift)
      }
    }

    func isDown(_ flags: CGEventFlags) -> Bool {
      switch self {
      case .command:
        return flags.contains(.maskCommand)
      case .control:
        return flags.contains(.maskControl)
      case .option:
        return flags.contains(.maskAlternate)
      case .shift:
        return flags.contains(.maskShift)
      }
    }
  }

  private struct TapState {
    var lastTapAt: TimeInterval = 0
    var tapCount: Int = 0
  }

  private struct KeyBinding {
    let keyCode: UInt16
    let command: Bool
    let control: Bool
    let option: Bool
    let shift: Bool

    static func fromMap(_ raw: Any?) -> KeyBinding? {
      guard let map = raw as? [String: Any],
            let keyCode = map["keyCode"] as? Int else {
        return nil
      }
      return KeyBinding(
        keyCode: UInt16(keyCode),
        command: map["command"] as? Bool == true,
        control: map["control"] as? Bool == true,
        option: map["option"] as? Bool == true,
        shift: map["shift"] as? Bool == true
      )
    }

    func matches(
      keyCode: UInt16,
      command: Bool,
      control: Bool,
      option: Bool,
      shift: Bool
    ) -> Bool {
      return self.keyCode == keyCode
        && self.command == command
        && self.control == control
        && self.option == option
        && self.shift == shift
    }
  }
}
