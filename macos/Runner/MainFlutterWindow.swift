import Cocoa
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

    channel.setMethodCallHandler { call, result in
      switch call.method {
      case "configure":
        let args = call.arguments as? [String: Any]
        monitor.configure(modifierKeyRaw: args?["modifierKey"] as? String)
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

  private var modifierKey: ModifierKey = .command
  private var eventTap: CFMachPort?
  private var runLoopSource: CFRunLoopSource?
  private var globalMonitor: Any?
  private var localMonitor: Any?

  private var lastHandledAt: TimeInterval = 0
  private var lastTapAt: TimeInterval = 0
  private var tapCount: Int = 0

  init(channel: FlutterMethodChannel, window: NSWindow) {
    self.channel = channel
    self.window = window
  }

  func configure(modifierKeyRaw: String?) {
    modifierKey = ModifierKey(rawValue: modifierKeyRaw ?? "") ?? .command
  }

  func start() {
    stop()

    if #available(macOS 10.15, *) {
      if !CGPreflightListenEventAccess() {
        CGRequestListenEventAccess()
      }
    }

    localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
      self?.handle(event: event, isGlobal: false)
      return event
    }
    globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
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
    lastHandledAt = 0
    lastTapAt = 0
    tapCount = 0
  }

  private func startEventTap() -> Bool {
    let mask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
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
      break
    case .tapDisabledByTimeout, .tapDisabledByUserInput:
      if let eventTap {
        CGEvent.tapEnable(tap: eventTap, enable: true)
      }
      return
    default:
      return
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
    guard modifierKey.keyCodes.contains(keyCode) else { return }
    // 修飾キー単体のダブルタップのみを対象にする（Cmd+Shift+V 等のショートカットを誤検知しない）
    guard modifierKey.isExclusiveDown(event.flags) else { return }
    handleTap()
  }

  private func handle(event: NSEvent, isGlobal: Bool) {
    // 前面かつ表示中のときはlocalMonitorで十分なので、globalMonitorは無視して二重発火を防ぐ
    if isGlobal && NSApp.isActive && !NSApp.isHidden {
      return
    }
    guard modifierKey.keyCodes.contains(event.keyCode) else { return }
    // 修飾キー単体のダブルタップのみを対象にする（Cmd+Shift+V 等のショートカットを誤検知しない）
    guard modifierKey.isExclusiveDown(event.modifierFlags) else { return }

    handleTap()
  }

  private func handleTap() {
    let now = ProcessInfo.processInfo.systemUptime
    if now - lastHandledAt <= 0.05 {
      return
    }
    lastHandledAt = now
    if now - lastTapAt <= 0.35 {
      tapCount += 1
    } else {
      tapCount = 1
    }
    lastTapAt = now

    guard tapCount >= 2 else { return }
    tapCount = 0
    trigger()
  }

  private func trigger() {
    DispatchQueue.main.async { [weak self] in
      guard let self else { return }

      let window = self.window
        ?? NSApp.keyWindow
        ?? NSApp.mainWindow
        ?? NSApp.windows.first(where: { $0.isVisible })
        ?? NSApp.windows.first

      // アプリがアクティブで、ウィンドウがキーウィンドウで、表示されていて、ミニマイズされていない場合のみ隠す
      // これにより、背面にあるウィンドウは前面に持ってこられる
      let isActiveAndForeground = NSApp.isActive
        && !NSApp.isHidden
        && window?.isKeyWindow == true
        && window?.isVisible == true
        && window?.isMiniaturized == false

      if isActiveAndForeground {
        NSApp.hide(nil)
        return
      }

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
      self.channel.invokeMethod("onQuickLaunch", arguments: ["source": "macos"])
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

    func isExclusiveDown(_ flags: NSEvent.ModifierFlags) -> Bool {
      let relevant: NSEvent.ModifierFlags = [.command, .control, .option, .shift]
      let current = flags.intersection(relevant)
      switch self {
      case .command:
        return current == .command
      case .control:
        return current == .control
      case .option:
        return current == .option
      case .shift:
        return current == .shift
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

    func isExclusiveDown(_ flags: CGEventFlags) -> Bool {
      let relevant: CGEventFlags = [.maskCommand, .maskControl, .maskAlternate, .maskShift]
      let current = flags.intersection(relevant)
      switch self {
      case .command:
        return current == .maskCommand
      case .control:
        return current == .maskControl
      case .option:
        return current == .maskAlternate
      case .shift:
        return current == .maskShift
      }
    }
  }
}
