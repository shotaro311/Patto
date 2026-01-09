# Patto!

パッと開いてパッとメモする、軽量メモアプリ（macOS / iOS）。

## 開発（ローカル）

- 依存関係: `flutter pub get`
- Isar 生成: `dart run build_runner build -d`
- 静的解析: `flutter analyze`
- テスト: `flutter test`

### 実行

- ローカルのみ（ログイン不要）: `flutter run`
- 同期を使う（Supabase）:
  - Supabaseのテーブル作成: `docs/sample/supabase_schema.sql` をSQLエディタで実行
  - `--dart-define=SUPABASE_URL=<your_url>`
  - `--dart-define=SUPABASE_ANON_KEY=<your_anon_key>`

AIモデル名を変える場合:
- `--dart-define=AI_MODEL_NAME=<model_name>`

## macOSクイック起動

装飾キーのダブルタップが反応しない場合、macOSの「入力監視（Input Monitoring）」権限が必要なことがあります。

※ダブルタップは「アプリが起動中（常駐中）」のときのみ有効です（初回は通常起動してください）。

また、ウィンドウの×で閉じてもアプリは終了せず、バックグラウンドに常駐します（終了は `Cmd+Q`）。
