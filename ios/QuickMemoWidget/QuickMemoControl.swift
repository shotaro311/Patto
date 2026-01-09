import WidgetKit
import SwiftUI
import AppIntents

@available(iOS 18.0, *)
enum QuickMemoTarget: String, AppEnum {
  case quickMemo

  static var typeDisplayRepresentation: TypeDisplayRepresentation {
    TypeDisplayRepresentation(name: "Patto!")
  }

  static var caseDisplayRepresentations: [QuickMemoTarget: DisplayRepresentation] {
    [
      .quickMemo: DisplayRepresentation(title: "クイックメモ"),
    ]
  }
}

@available(iOS 18.0, *)
struct OpenQuickMemoIntent: OpenIntent {
  static var title: LocalizedStringResource = "クイックメモ"
  static var openAppWhenRun = true
  static var isDiscoverable = true

  @Parameter(title: "ターゲット")
  var target: QuickMemoTarget

  init() {
    target = .quickMemo
  }

  @MainActor
  func perform() async throws -> some IntentResult {
    QuickMemoControlStore.requestOpen()
    return .result()
  }
}

@available(iOS 18.0, *)
struct QuickMemoControl: ControlWidget {
  var body: some ControlWidgetConfiguration {
    StaticControlConfiguration(kind: "QuickMemoControl") {
      ControlWidgetButton(action: OpenQuickMemoIntent()) {
        Label("クイックメモ", systemImage: "square.and.pencil")
      }
    }
    .displayName("クイックメモ")
    .description("クイックメモを開きます。")
  }
}
