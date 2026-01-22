# Parallel Development Workflow（並行開発 運用）

## 目的
- 並行開発を「速さ」ではなく「統合の安全性」で運用する。

## 役割
- parallel-dev-auto: 状態を見て architect/worker を自動判定
- parallel-dev-architect: DAG/契約/指示書/worktree を整備
- parallel-dev-worker: task.md を読み、担当範囲に集中して実装

## 起動タイミング
- ユーザーが「並行開発を開始したい」と言ったタイミングで parallel-dev-auto を起動する
- docs/pdev が無い場合は architect として開始し、ある場合は task.md の有無で worker へ切り替える

## ワーカー数（同時起動）
- 同時に動かす worker の数（= worktree の数）を決める
- 上限: 3
- 推奨: 1〜2 / 必要なら3（統合（レビュー・衝突解消・テスト）が重くなる前提）

## worktree / branch ルール（例）
- RUN_ID: `YYYYMMDD-HHMM` など
- branch: `pdev/<RUN_ID>/<TASK_ID>-<slug>`
- worktree: `pdev-1`, `pdev-2` など

## 統合（マージ）の進め方
- PR は同時にマージするのではなく、1 本ずつ順番にマージする
- 各マージ後に「ビルド」「主要テスト」「動作確認」を実行し、問題が無いことを確認してから次へ進む
- merge はエディタ依存で止まらないように、`git merge --no-ff -m "merge: <TASK_ID> <title>" <branch>` を推奨する

## 終了
- すべての worker 完了をユーザーが確認したら、architect が docs/pdev を `docs/00_old/` にアーカイブする
- その後、worktree を削除して並行開発を閉じる

## 進捗報告の最小フォーマット
- `T1終了` / `done: T1` のように短く送る
- アーキテクトは `docs/pdev/active/TASKS.md` を参照して該当 task.md を確認する
