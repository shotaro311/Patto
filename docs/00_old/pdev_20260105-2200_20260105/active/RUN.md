# Parallel Dev RUN

## RUN メタ情報
- RUN_ID: 20260105-2200
- 作成日: 2026-01-05
- ベースブランチ: main（初期コミット前）
- ワーカー数（同時起動）: 2
- worktree: 未作成（初期コミット前のため）。このRUNは単一作業ツリーで順番に実施する。

## 読んだ入力（仕様ソース）
- requirement:
  - `docs/requirement/requirements.md`
- planning:
  - `docs/plan/20260105_PLAN1.md`
- 追加指示:
  - MVP: macOS/iOS、AIは文章編集のみ必須、同期ON時のみログイン必須（初期はローカル自動取り込み）
  - クイック起動: macOSは装飾キーダブルタップ、iOSも即入力導線（例: クイックアクション等）

## DAG（参照）
- `docs/pdev/DAG.md`

## タスク割り当て
- pdev-1: T1 ローカル/UI + AI
- pdev-2: T2 同期/認証

## 合流順（提案）
- 1) T0（基盤）
- 2) T1
- 3) T2

## 未確定事項（ユーザー判断が必要）
- [ ] （iOS）ロック画面起動の最小実装（OS制約あり）
- [ ] 競合解決UI（現状は競合時に別メモとして保存）
- [ ] LWWの時計ズレ対策
