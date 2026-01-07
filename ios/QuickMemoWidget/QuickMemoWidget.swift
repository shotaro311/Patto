import WidgetKit
import SwiftUI

struct QuickMemoEntry: TimelineEntry {
  let date: Date
}

struct QuickMemoProvider: TimelineProvider {
  func placeholder(in context: Context) -> QuickMemoEntry {
    QuickMemoEntry(date: Date())
  }

  func getSnapshot(in context: Context, completion: @escaping (QuickMemoEntry) -> Void) {
    completion(QuickMemoEntry(date: Date()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<QuickMemoEntry>) -> Void) {
    let entry = QuickMemoEntry(date: Date())
    completion(Timeline(entries: [entry], policy: .never))
  }
}

struct QuickMemoWidgetView: View {
  @Environment(\.widgetFamily) var family

  var body: some View {
    Link(destination: URL(string: "patto://quick-memo")!) {
      contentView
    }
    .widgetBackground()
  }

  @ViewBuilder
  private var contentView: some View {
    switch family {
    case .systemSmall, .systemMedium:
      VStack(alignment: .leading, spacing: 8) {
        Text("クイックメモ")
          .font(.headline)
        Text("すぐに入力できます")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .padding()
    case .accessoryCircular:
      Image(systemName: "square.and.pencil")
    case .accessoryInline:
      Text("クイックメモ")
    case .accessoryRectangular:
      HStack {
        Image(systemName: "square.and.pencil")
        Text("クイックメモ")
          .font(.caption)
      }
    default:
      Text("クイックメモ")
    }
  }
}

private extension View {
  @ViewBuilder
  func widgetBackground() -> some View {
    if #available(iOS 17.0, *) {
      self.containerBackground(.fill.tertiary, for: .widget)
    } else {
      self
    }
  }
}

struct QuickMemoWidget: Widget {
  let kind = "QuickMemoWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: QuickMemoProvider()) { _ in
      QuickMemoWidgetView()
    }
    .configurationDisplayName("クイックメモ")
    .description("すぐにメモ入力を開きます。")
    .supportedFamilies([
      .systemSmall,
      .systemMedium,
      .accessoryCircular,
      .accessoryInline,
      .accessoryRectangular,
    ])
  }
}

@main
struct QuickMemoWidgetBundle: WidgetBundle {
  var body: some Widget {
    QuickMemoWidget()
    if #available(iOS 18.0, *) {
      QuickMemoControl()
    }
  }
}
