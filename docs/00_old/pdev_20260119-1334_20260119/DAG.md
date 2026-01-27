# Parallel Dev DAG

## DAG サマリー（ノードと依存）
> 形式: `TASK_ID: depends_on -> [ ... ]`

- T0: depends_on -> []
- T1: depends_on -> [T0]
- T2: depends_on -> [T0]

## タスク一覧
### T0: 設定モデル/永続化の基盤整備
- 目的:
  - 新規要件の設定項目を AppSettings/SharedPreferences に追加し、共通型と読み書きを確定する
- 依存: []
- 並行可否: 不可（共有境界のため先行）
- SCOPE（変更対象）:
  - `lib/domain/app_settings.dart`
  - `lib/presentation/providers/app_settings_controller.dart`
  - 必要に応じて `lib/domain/**` の新規型
- 共有境界（触るなら基盤タスクへ）:
  - 設定キー/データ型/永続化
- 成果物:
  - 設定の追加（デフォルト値含む）
- テスト/確認:
  - ビルド: `flutter analyze`
  - 手動: 設定読み込みで例外が出ない

### T1: ホットキー拡張 + クリップボード連携（macOS）
- 目的:
  - 既存のダブルタップに加え、通常キーバインドの設定を追加
  - 非表示時コピー / 表示時貼り付け（別ホットキー）を実装
- 依存: [T0]
- 並行可否: 可（T0完了後）
- SCOPE（変更対象）:
  - `lib/services/shortcut_service.dart`
  - `lib/app.dart`
  - `lib/presentation/screens/settings_screen.dart`（ホットキー関連セクション）
  - `macos/Runner/MainFlutterWindow.swift`
  - 必要に応じて `lib/presentation/providers/**`
- 共有境界（触るなら基盤タスクへ）:
  - AppSettingsの型/キー
- 成果物:
  - グローバルホットキー（ダブルタップ/通常）の設定と動作
  - 非表示時コピー/表示時貼り付けの追加オプション
- テスト/確認:
  - 手動: macOSでダブルタップ/通常キーバインドの動作確認
  - 手動: 非表示時コピー/表示時貼り付けの挙動

### T2: AI編集拡張 + 文字数表示
- 目的:
  - AI編集のプレビュー/差分/再プロンプト/カスタムプロンプト/通知を実装
  - 文字数表示（設定ON/OFF、右下表示）を実装
- 依存: [T0]
- 並行可否: 可（T0完了後）
- SCOPE（変更対象）:
  - `lib/presentation/screens/note_editor_pane.dart`
  - `lib/presentation/screens/settings_screen.dart`（AI/文字数セクション）
  - `lib/services/ai_service.dart`
  - `lib/presentation/providers/ai_providers.dart`（必要なら）
  - 必要に応じて `lib/presentation/widgets/**`
- 共有境界（触るなら基盤タスクへ）:
  - AppSettingsの型/キー
- 成果物:
  - AI編集の新UI/操作/通知仕様
  - 文字数表示のUI/設定
- テスト/確認:
  - 手動: AI編集のフロー（プレビューON/OFF、キャンセル、失敗）
  - 手動: 文字数表示のON/OFF
