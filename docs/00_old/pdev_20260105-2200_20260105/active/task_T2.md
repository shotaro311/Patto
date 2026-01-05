# task.md

ROLE: worker
RUN_ID: 20260105-2200
TASK_ID: T2
TASK_NAME: 同期/認証
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
- [x] 同期ON→ログイン→既存ローカルメモを自動アップロード
- [x] 差分同期（server_updated_at > lastSyncAt）ができる

## SCOPE（変更対象）
- Allowed:
  - `lib/services/sync_service.dart`
  - `lib/services/auth_service.dart`
  - `lib/presentation/providers/*supabase*`
  - `lib/presentation/providers/sync_*`
  - `lib/presentation/screens/auth_screen.dart`
- Touchpoints（参照/呼び出しOK）:
  - `lib/data/**`
  - `lib/domain/**`

## 変更内容サマリー（完了時に埋める）
- 変更概要（3〜7行）:
  - Supabaseの任意ログイン（同期ON時のみ）と、初期取り込み（ローカル→クラウド）を実装
  - 差分同期（server_updated_at 기준）と lastSyncAt の保存を実装
  - 競合時は別メモとして保存（UIでの選択解決はTODO）
- 変更ファイル:
  - `lib/services/sync_service.dart`
  - `lib/services/auth_service.dart`
  - `lib/presentation/screens/auth_screen.dart`
  - `lib/presentation/providers/sync_providers.dart`
  - `lib/presentation/providers/supabase_providers.dart`
- 動作確認手順:
  1) Supabase設定（`SUPABASE_URL` / `SUPABASE_ANON_KEY`）を `--dart-define` で渡す
  2) アプリで「同期を有効化」→ ログイン → 「同期」
- リスク/ロールバック観点:
  - server_updated_at の更新をクライアント時刻に依存（時計ズレ対策はTODO）
