# Parallel Dev Launch Guide

## 1) 事前準備（main）
- main を最新化してから始める（例: `git fetch` → `git pull --ff-only`）
- 依存関係のインストールや基本ビルドが必要なら、README の手順を優先して実施する

## 2) worktree 確認
- `cd /Users/shotaro/code/shared/Patto/.worktrees/pdev-1`
- `cd /Users/shotaro/code/shared/Patto/.worktrees/pdev-2`

## 3) worker 起動（Codex CLI）

### pdev-1（T1）
```bash
codex exec -C "/Users/shotaro/code/shared/Patto/.worktrees/pdev-1" -o "/Users/shotaro/code/shared/Patto/.worktrees/pdev-1/.codex_last_message.md" - <<'PROMPT'
あなたは parallel-dev-worker です。まず task.md を読み、SCOPE 内だけを実装してください。完了したら done: T1 を1行で出して終了してください。
PROMPT
```

### pdev-2（T2）
```bash
codex exec -C "/Users/shotaro/code/shared/Patto/.worktrees/pdev-2" -o "/Users/shotaro/code/shared/Patto/.worktrees/pdev-2/.codex_last_message.md" - <<'PROMPT'
あなたは parallel-dev-worker です。まず task.md を読み、SCOPE 内だけを実装してください。完了したら done: T2 を1行で出して終了してください。
PROMPT
```

## 4) 終了
- worker の完了報告後、順に合流して動作確認を行う
- すべて終わったら docs/pdev をアーカイブし、worktree を削除する
