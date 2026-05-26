# Parallel Development Contract（並行開発 契約）

## 目的
複数エージェントの並行作業を、速さではなく「壊れずに合流できること」を最優先で運用する。

## この契約の使い方
- 並行作業は、この契約と DAG に従って進める。
- 契約の変更は、ワーカー単独の判断ではなく、アーキテクトへ提案して更新する。

## 用語
- RUN: 今回の並行開発のひとまとまり（RUN_IDで識別）
- Task: DAG のノード。依存関係と成果物を持つ
- Architect: DAG/契約/指示書/worktree を整える役割
- Worker: task.md の範囲に集中して実装する役割

## 並行化の原則
- 依存がある作業ではなく、依存がない作業を並行化する。
- マージ（統合）は同時ではなく、1 本ずつ順番に行う。

## 変更領域の境界（責務分離）
### ワーカーが集中する範囲
- task.md に書かれた SCOPE の変更に集中する
- 共有境界（型・設定・ルーティング等）に変更が必要な場合は、作業で押し切るのではなく「基盤タスクへの切り出し」を提案する

### アーキテクトが扱う範囲
- DAG と契約の作成・更新
- 共有境界を触る基盤タスクの実行（必要な場合）
- worktree/ブランチの作成と終了処理

## 成果物（ワーカーのアウトプット）
- 実装は、PR または diff で提出できる形にまとめる
- 受け入れのために必要な情報を残す:
  - 変更概要（3〜7行）
  - 変更ファイル一覧
  - 動作確認手順
  - リスクとロールバック観点

## 進捗共有
- 進捗共有は会話だけではなく、task.md の「進捗ログ」を更新して残す
- ブロッカーは抱えるのではなく、早めに「依存」「質問」として明文化する

---

# 今回の契約（メモ入力の画像/リンク/AI対応）

## 仕様の一次情報
- PLAN: `docs/plan/20260201_PLAN1.md`
- 共通ルール: `AGENTS.md`

## 共有境界（固定）
- 画像添付は **本文とは別の添付/カード表示**（本文はプレーンテキスト維持）
- 画像AIコンテキストは **メモ上部トグルでON/OFF**
- AI画像送信の上限は **設定で変更可（デフォルト3）**
- URLは **文中すべて自動リンク化**、右クリックで **URLコピー/ブラウザ表示**
- PDF解析は **今回保留**

## 共有インターフェース（合意）
- Isarモデル（案）: `NoteAttachment`
  - `uuid`（unique）/ `noteId` / `localPath` / `mimeType`
  - `width` / `height` / `byteSize` / `createdAt` / `sortIndex`
- Repository API（案）:
  - `watchAttachments(noteId)` → `Stream<List<NoteAttachment>>`
  - `addAttachmentFromBytes(noteId, bytes, {originalName})` → `NoteAttachment`
  - `deleteAttachment(attachmentUuid)`
- Settings（案）:
  - `aiImageContextMaxCount`（int, default 3）

## 変更範囲の分担
- T1: データ層/設定（モデル・Repository・WebP変換・Settings画面）
- T2: UI/AI/URL（NoteEditor/QuickMemo/AI編集・リンク化）

## 衝突回避ルール
- `note_editor_pane.dart` / `quick_memo_screen.dart` は **T2のみ**が変更
- `app_settings.dart` / `app_settings_controller.dart` / `settings_screen.dart` は **T1のみ**が変更
- モデル/API名の変更が必要な場合は **Architectへ相談**
