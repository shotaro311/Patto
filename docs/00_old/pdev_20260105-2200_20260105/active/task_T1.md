# task.md

ROLE: worker
RUN_ID: 20260105-2200
TASK_ID: T1
TASK_NAME: ローカル/UI + AI
BRANCH: (未作成)
BASE_BRANCH: main
WORKTREE: (単一作業ツリー)
OWNER_AGENT: codex
PUSH_POLICY: ask

## ゴール（Done の定義）
- [x] 要件（requirement）に沿って期待動作が満たされている
- [x] 受け入れ条件が満たされている
- [x] 手元で最低限のビルド/テストが通る
- [x] 合流担当がレビューできる情報（変更概要/テスト手順/注意点）が揃っている

### 受け入れ条件（具体）
- [x] ログイン不要でメモ作成/編集/削除/検索ができる
- [x] Markdownプレビューができる
- [x] AI文章編集（置換/追記）ができる（APIキーは端末保存）

## SCOPE（変更対象）
- Allowed:
  - `lib/presentation/**`
  - `lib/services/ai_*`
- Touchpoints（参照/呼び出しOK）:
  - `lib/data/**`
  - `lib/domain/**`

## 変更内容サマリー（完了時に埋める）
- 変更概要（3〜7行）:
  - ローカルメモのCRUD/検索/Markdownプレビューを実装
  - 設定画面（AIキー保存、クイック起動の挙動、同期トグル）を実装
  - AI文章編集（置換/追記）を実装
- 変更ファイル:
  - `lib/presentation/screens/notes_home_screen.dart`
  - `lib/presentation/screens/note_editor_pane.dart`
  - `lib/presentation/screens/settings_screen.dart`
  - `lib/services/ai_service.dart`
  - `lib/services/ai_key_repository.dart`
- 動作確認手順:
  1) `dart run build_runner build -d`
  2) `flutter analyze`
  3) `flutter test`
- リスク/ロールバック観点:
  - AIはユーザーAPIキー必須（未設定時はエラー表示）
  - AI送信の注意文は表示しているが、細かい文言は調整余地あり
