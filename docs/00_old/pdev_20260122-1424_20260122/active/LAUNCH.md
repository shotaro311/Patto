# Parallel Dev Launch Guide

## 1) 事前準備（main）
- main を最新化してから始める（例: `git fetch` → `git pull --ff-only`）
- 依存関係のインストールや基本ビルドが必要なら、README の手順を優先して実施する

## 2) worktree 確認
- worktree ごとに繰り返す:
  - `cd <worktree_path>`
  - `ls` で `task.md` があることを確認

### 今回の worktree
- pdev-1: `/Users/shotaro/code/shared/Patto-pdev-1`
- pdev-2: `/Users/shotaro/code/shared/Patto-pdev-2`

## 3) worker 起動（推奨: Codex CLI を別プロセスで起動）

別ターミナル（またはバックグラウンド）で、worktree ごとに `codex exec` を起動する。

### 例（任意の worktree）
```bash
codex exec -C "<worktree_path>" -o "<worktree_path>/.codex_last_message.md" - <<'PROMPT'
あなたは parallel-dev-worker です。まず task.md を読み、SCOPE 内だけを実装してください。完了したら done: <TASK_ID> を1行で出して終了してください。
PROMPT
```

（補足）バックグラウンドで動かす場合は、ログを残す:
```bash
codex exec -C "<worktree_path>" -o "<worktree_path>/.codex_last_message.md" - < prompt.md > "<worktree_path>/codex.log" 2>&1 &
```

## 4) 終了
- worker が「完了報告」し、ユーザーが OK を出したタスクから順に PR を更新/統合する
- すべて終わったら architect に「並行開発終了」と伝える
