# Parallel Dev RUN

## RUN メタ情報
- RUN_ID: 20260201-1319
- 作成日: 2026-02-01
- ベースブランチ: feat/memo-media-link-ai
- ワーカー数（同時起動）: 2
- worktree:
  - pdev-1: pdev/20260201-1319/T1-data
  - pdev-2: pdev/20260201-1319/T2-ui

## 読んだ入力（仕様ソース）
- requirement:
  - なし（PLANに集約）
- planning:
  - `docs/plan/20260201_PLAN1.md`
- 追加指示:
  - 画像は本文とは別の添付/カード表示（B案）
  - URLは文中すべて自動リンク化、右クリックでURLコピー/ブラウザ表示
  - 画像AIはメモ上部トグルでON/OFF
  - 画像AIの最大枚数は設定で変更、デフォルト3
  - APIコスト増の注意書き
  - 画像右クリックは既存AI編集仕様
  - AI編集後に画像は削除しない
  - PDF解析は保留

## DAG（参照）
- `docs/pdev/DAG.md`

## タスク割り当て
- pdev-1: T1 画像添付のデータ層/設定
- pdev-2: T2 メモUI拡張（画像/AI/URL）

## 合流順（提案）
- 1) T1 → feat/memo-media-link-ai
- 2) T2 → feat/memo-media-link-ai
- 3) T3（統合/調整）

## 未確定事項（ユーザー判断が必要）
- [ ] 画像入力（貼付/ドラッグ/選択）の対象プラットフォーム
- [ ] PDFの入力形式（ページ画像化/ファイル直接送信）

## 決定事項
- WebP変換は `image` パッケージで実装
