# Parallel Dev DAG

## DAG サマリー（ノードと依存）
> 形式: `TASK_ID: depends_on -> [ ... ]`

- T0: depends_on -> []（基盤）
- T1: depends_on -> [T0]（ローカル/UI）
- T2: depends_on -> [T0]（同期/認証）

## タスク一覧
### T0: 基盤（モデル/設定/初期化）
- 目的: 並行実装の共有境界を先に固定する
- 依存: []
- 並行可否: 不可（共有境界）
- SCOPE（変更対象）:
  - `pubspec.yaml`
  - `lib/core/**`
  - `lib/data/models/**`
  - `lib/data/datasources/**`
  - `lib/main.dart`
  - `lib/app.dart`
- 共有境界:
  - Noteモデル（uuid/dirty等）
  - 設定（同期ON/AIキー/クイック起動）
  - MethodChannel名: `com.patto/quick_launch`
- テスト/確認:
  - `dart run build_runner build -d`
  - `flutter analyze`

### T1: ローカルメモ（CRUD/検索/Markdown）+ AI文章編集
- 目的: ログイン不要で「パッと入力」できる体験を作る
- 依存: [T0]
- 並行可否: 可（同期領域と分離）
- SCOPE（変更対象）:
  - `lib/presentation/screens/**`
  - `lib/presentation/providers/**`
  - `lib/services/ai_*`
- 受け入れ条件:
  - メモ作成/編集/削除/検索が動作する
  - Markdownプレビューができる
  - AI文章編集（置換/追記）ができる（キーは端末保存）
- テスト/確認:
  - `flutter test`

### T2: 同期（任意ログイン）+ 初期取り込み
- 目的: 同期ON時のみログイン→既存ローカルが自動アップロードされる
- 依存: [T0]
- 並行可否: 可（ローカルUIと分離）
- SCOPE（変更対象）:
  - `lib/services/sync_service.dart`
  - `lib/services/auth_service.dart`
  - `lib/presentation/providers/*supabase*`
  - `lib/presentation/providers/sync_*`
  - `lib/presentation/screens/auth_screen.dart`
- 受け入れ条件:
  - 同期ON→ログイン→同期が走る
  - lastSyncAt が保存され、差分同期できる
