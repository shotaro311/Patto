# macOS 選択テキスト反映（ホットキー起動）検討ログ（2026-01-19〜2026-01-20）

## 結論（2026-01-20）
- **Mac App Store（App Sandbox ON）前提では、他アプリの選択テキストを取得してメモ欄に反映する方式は見送り**。
- そのため、現在の実装は「表示/非表示のホットキー（ダブルタップ/通常キーバインド）」のみ。
- 併せて「非表示時コピー」も削除。

## 概要
- 当初は「他アプリで選択中のテキストを取得して、ホットキー起動時にメモ欄へ反映」する挙動を目指した。
- `Cmd+C` 経由は「選択なしでも行がコピーされる」副作用があり、改善を試みた。
- アクセシビリティ（AX）経由は **App Sandbox OFF では動くが、ON では取得できない**状況になり、Mac App Store 前提のため採用不可となった。

## 変更点（差分）
※ここに記載の差分は「当時の試行」で、現在は機能自体を削除しています。

### 1) `triggerPaste()` のテキスト送信
```diff
- if NSApp.isActive && !NSApp.isHidden {
-   self.channel.invokeMethod("onQuickLaunch", arguments: [
-     "source": "macos",
-     "action": "paste",
-   ])
-   return
- }
- captureSelectedText { text in
-   self.showApp(window: window)
-   self.channel.invokeMethod("onQuickLaunch", arguments: [
-     "source": "macos",
-     "action": "paste",
-     "text": text ?? "",
-   ])
- }
+ captureSelectedText { text in
+   if !(NSApp.isActive && !NSApp.isHidden) {
+     self.showApp(window: window)
+   }
+   self.channel.invokeMethod("onQuickLaunch", arguments: [
+     "source": "macos",
+     "action": "paste",
+     "text": text ?? "",
+   ])
+ }
```

### 2) `captureSelectedText()` を Cmd+C 経由に戻す
```diff
- // アクセシビリティで選択範囲を判定し、選択なしは貼り付けしない
- // readFocusedElement / readSelectedTextRangeInfo / readSelectedText を使用
- ...
+ let pasteboard = NSPasteboard.general
+ let previousChangeCount = pasteboard.changeCount
+ postCopyCommand()
+ DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
+   let currentChangeCount = pasteboard.changeCount
+   guard currentChangeCount != previousChangeCount else {
+     completion(nil)
+     return
+   }
+   let text = pasteboard.string(forType: .string)
+   completion(text?.isEmpty == false ? text : nil)
+ }
```

## 既知の影響
- `Cmd+C` 方式では、IDE等で「選択なしでも行がコピーされる」挙動が発生しうる。
- AX方式は App Sandbox ON では成立しなかった（Mac App Store 配布前提のため採用不可）。

## 変更ファイル
- `macos/Runner/MainFlutterWindow.swift`
