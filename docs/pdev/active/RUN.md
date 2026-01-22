# Parallel Dev RUN

## RUN メタ情報
- RUN_ID: 20260122-1424
- 作成日: 2026-01-22
- ベースブランチ: chore/plan-20260117-next-features
- ワーカー数（同時起動）: 2
- worktree:
  - pdev-1: pdev/20260122-1424/t1-quickmemo-inbox
  - pdev-2: pdev/20260122-1424/t2-auto-organize-suggest

## 読んだ入力（仕様ソース）
- requirement:
  - docs/requirement/requirements.md
- planning:
  - docs/plan/20260117_PLAN1.md
- 追加指示:
  - macOS先行で実装する
  - 下書きは複数保持し、上限超過は自動アーカイブ（通常メモ扱いへ移す）
  - 自動整理（タグ/リンク/AI）は「提案」モード（確認して適用）が既定
  - フォルダ整理は一旦保留（タグ/リンク自動整理を優先）
  - 並行開発は2ワーカーで開始し、最後にworktree削除まで実施する

## DAG（参照）
- `docs/pdev/DAG.md`

## タスク割り当て
- architect: T0 基盤（モデル/永続化/移行方針の確定）
- pdev-1: T1 下書きInbox UI/フロー
- pdev-2: T2 自動整理（タグ/リンク/AI提案）最小実装

## 合流順（提案）
- 1) T0（基盤）をベースブランチへコミット
- 2) T1 をベースへ統合
- 3) T2 をベースへ統合
- 4) T3（統合後の調整/テスト）をベースで実施

## 未確定事項（ユーザー判断が必要）
- [ ] 下書き保持数（上限）の具体値
- [ ] 自動整理の提案UI（どこに出すか：クイックメモ/編集画面/サイドバー）
