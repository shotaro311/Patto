# task.md

ROLE: worker
RUN_ID: [YYYYMMDD-HHMM]
TASK_ID: [T1]
TASK_NAME: [タスク名]
BRANCH: pdev/[RUN_ID]/[TASK_ID]-[slug]
BASE_BRANCH: [main]
WORKTREE: [pdev-1]
OWNER_AGENT: [codex/claude]
PUSH_POLICY: ask  # auto | ask

## ゴール（Done の定義）
- [ ] 要件（requirement）に沿って期待動作が満たされている
- [ ] 受け入れ条件が満たされている
- [ ] 手元で最低限のビルド/テストが通る
- [ ] 合流担当がレビューできる情報（変更概要/テスト手順/注意点）が揃っている

### 受け入れ条件（具体）
- [ ] ...
- [ ] ...

## SCOPE（変更対象）
- Allowed:
  - `path/to/feature/**`
- Touchpoints（参照/呼び出しOK）:
  - `path/to/shared/**`
- 外部I/O:
  - 入力:
  - 出力:

## 実装プラン（ワーカー用）
- [ ] 現状把握
- [ ] 方針確定
- [ ] 実装
- [ ] テスト/動作確認
- [ ] 変更概要と手順整理
- [ ] push/PR更新（PUSH_POLICY に従う）
- [ ] 完了報告

## 進捗ログ
> 形式例: `YYYY-MM-DD HH:MM` / 状態 / 実績 / 次 / ブロッカー

- YYYY-MM-DD HH:MM:
  - 状態:
  - 実績:
  - 次:
  - ブロッカー:

## 変更内容サマリー（完了時に埋める）
- 変更概要（3〜7行）:
- 変更ファイル:
  - -
- 動作確認手順:
  1)
  2)
- リスク/ロールバック観点:
- PR:
  - URL:
