# Parallel Dev DAG

## DAG サマリー（ノードと依存）
> 形式: `TASK_ID: depends_on -> [ ... ]`

- T1: depends_on -> []
- T2: depends_on -> []
- T3: depends_on -> [T1, T2]（統合/調整）

## タスク一覧
### T1: 画像添付のデータ層/設定
- 目的: 画像添付の永続化とWebP保存、AI画像上限設定の追加
- 依存: []
- 並行可否: 可（UIとは分離）
- SCOPE（変更対象）:
  - `lib/data/models/**`
  - `lib/data/repositories/**`
  - `lib/services/**`
  - `lib/domain/app_settings.dart`
  - `lib/presentation/providers/app_settings_controller.dart`
  - `lib/presentation/screens/settings_screen.dart`
  - `pubspec.yaml`
- 共有境界（触るなら基盤タスクへ）:
  - モデル名/Repository API/設定キー
- 成果物:
  - PR または diff
- テスト/確認:
  - ビルド: 必要に応じて
  - 手動確認: 設定画面で上限が変更できる

### T2: メモUI拡張（画像/AI/URL）
- 目的: 画像表示/入力、AI編集の画像対応、URL自動リンク化
- 依存: []（契約に従って並行実装）
- 並行可否: 可（T1と責務分離）
- SCOPE（変更対象）:
  - `lib/presentation/screens/note_editor_pane.dart`
  - `lib/presentation/screens/quick_memo_screen.dart`
  - `lib/services/ai_service.dart`
- 共有境界（触るなら基盤タスクへ）:
  - Repository API/設定キー
- 成果物:
  - PR または diff
- テスト/確認:
  - 手動確認: 画像表示/URLリンク/AI編集

### T3: 統合/調整（Architect）
- 目的: T1/T2の衝突解消・最終統合
- 依存: [T1, T2]
- 並行可否: 不可
- テスト/確認:
  - 手動確認: 主要導線の通し確認
