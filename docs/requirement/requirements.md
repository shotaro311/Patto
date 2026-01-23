# Patto! - 要件定義書

## 1. プロジェクト概要

### 1.1 プロダクト名
**Patto!**（パッと開いてパッとメモする、の意）

### 1.2 目的
macOS / iOS を中心に、パッと起動してすぐ入力できる軽量メモアプリを開発する。
シンプルで高速な操作性を重視し、ローカルのみでも使え、同期を使うときだけログインしてデバイス間で同期できるメモ環境を提供する。

### 1.3 MVP（Minimum Viable Product）
- 対象プラットフォーム: **macOS + iOS**
- 主要機能:
  - メモの作成・編集・削除、Markdown対応、ローカル検索
  - オフライン対応（常時）
  - 同期（ログイン時のみ）
  - AI文章編集（文章編集のみ。要約/翻訳などはMVP後）
  - クイック起動で「即入力」できること（macOS/iOS）

### 1.4 将来的な拡張
- Windows / Android 対応
- 音声入力機能（MVP後）
- AI機能拡張（例: 要約/校正/翻訳）

---

## 2. 機能要件

### 2.1 MVP機能

#### 2.1.1 メモ機能
| ID | 機能 | 説明 | 優先度 |
|----|------|------|--------|
| F-001 | メモ作成 | 新規メモの作成 | 必須 |
| F-002 | メモ編集 | 既存メモの編集（Markdown対応） | 必須 |
| F-003 | メモ削除 | メモの削除（削除後14日で完全削除） | 必須 |
| F-004 | メモ一覧 | 保存済みメモの一覧表示 | 必須 |
| F-005 | メモ検索 | タイトル・本文でのローカル検索 | 必須 |
| F-006 | Markdown入力 | Markdown記法の入力に対応（プレビューなし） | 必須 |
| F-007 | タイトル編集 | タイトルを手動編集できる（重複時はエラー） | 必須 |

#### 2.1.5 タグ/リンクによる自動整理
| ID | 機能 | 説明 | 優先度 |
|----|------|------|--------|
| F-040 | タグ（手動） | メモに手動でタグを付けられる（`manualTags`） | 必須 |
| F-041 | タグ（自動・提案） | AI等でタグ候補（`autoTags`）を生成し、**提案として提示**（確認して適用） | 必須 |
| F-042 | リンク | `[[リンク]]`等でメモ同士を関連付けできる（リンク一覧/参照元の表示はMVP内で最小） | 必須 |

#### 2.1.2 同期機能
| ID | 機能 | 説明 | 優先度 |
|----|------|------|--------|
| F-015 | ゲスト利用 | ログインなしでメモの作成・閲覧・編集ができる（ローカルのみ） | 必須 |
| F-010 | ユーザー認証 | 同期を有効化する場合のみ、メール/パスワードまたはOAuthでログイン | 必須 |
| F-011 | クラウド同期 | （ログイン時）Supabaseを使用したデバイス間同期 | 必須 |
| F-012 | オフライン対応 | ネットワーク未接続時もメモの閲覧・編集が可能 | 必須 |
| F-013 | 自動同期 | 保存確定時に自動同期（ログイン+同期ON時）。オンライン復帰時や定期ポーリングでも同期 | 必須 |
| F-014 | コンフリクト解決 | 同期時の競合を検出し、解決策を提示 | 必須 |

#### 2.1.3 AI文章編集機能
| ID | 機能 | 説明 | 優先度 |
|----|------|------|--------|
| F-020 | AI文章編集 | 選択テキストまたはメモ全体を、ユーザーの指示に従って書き換え | 必須 |
| F-021 | 編集結果の適用 | 生成結果を確認し、「適用（置換）/追記/キャンセル」を選べる | 必須 |
| F-022 | AI利用設定 | AIの利用可否、送信される内容の注意表示、ユーザーAPIキー登録（端末内に保存）、カスタムプロンプト（最大6）の編集 | 必須 |

#### 2.1.4 ショートカット機能
| ID | 機能 | 説明 | 優先度 |
|----|------|------|--------|
| F-030 | （macOS）クイック起動 | 装飾キーのダブルタップでアプリを表示/非表示（トグル）し、表示時は入力欄へフォーカス | 必須 |
| F-031 | ショートカット設定 | 使用する装飾キー（Cmd, Ctrl, Alt, Shift等）の選択 | 必須 |
| F-032 | （iOS）クイック起動 | ウィジェット（iOS 16+）/ロック画面コントロール（iOS 18+）から起動し、入力欄へフォーカス | 必須 |
| F-033 | クイック起動の挙動設定 | 「新規メモを開く / 前回メモを開く」を設定で選べる | 必須 |
| F-034 | クイックメモ | 「新規メモ」設定時はクイックメモ（下書き）を開き、入力を自動保存する。下書きは常に1件のみ保持する。保存（整理/確定）時に通常メモとして扱い、クイックメモは空に戻る。下書きがある場合、ホームに「下書き」導線を表示し、「＋」押下時に保存/編集/破棄を選べる | 必須 |
※ Mac App Store配布前提のため、他アプリの選択テキスト反映/非表示時コピーは対象外

### 2.2 将来機能（MVP後）

| ID | 機能 | 説明 |
|----|------|------|
| F-100 | 音声入力 | マイクからの音声をテキストに変換 |
| F-105 | AI要約 | メモ全体または選択テキストの要約 |
| F-106 | AI校正 | 文法・誤字脱字などの修正提案 |
| F-107 | AI翻訳 | 選択テキストの翻訳 |
| F-102 | フォルダ機能 | メモの階層的な整理 |
| F-103 | 共有機能 | 他ユーザーとのメモ共有 |
| F-104 | エクスポート | Markdown/PDF/テキスト形式でのエクスポート |

---

## 3. 非機能要件

### 3.1 パフォーマンス
| ID | 要件 | 目標値 |
|----|------|--------|
| NF-001 | アプリ起動時間 | 2秒以内 |
| NF-002 | メモ保存応答 | 100ms以内（ローカル） |
| NF-003 | 同期完了時間 | 5秒以内（100KB以下のメモ） |
| NF-004 | メモリ使用量 | 200MB以下（通常使用時） |

### 3.2 セキュリティ
| ID | 要件 | 説明 |
|----|------|------|
| NF-010 | 秘密情報の保護 | AI APIキー等はSecure Storageを使用して安全に保存（クラウド同期しない） |
| NF-011 | 認証トークン | Supabase JWT使用、自動リフレッシュ |
| NF-012 | 通信暗号化 | HTTPS必須 |

### 3.3 ユーザビリティ
| ID | 要件 | 説明 |
|----|------|------|
| NF-020 | オフライン通知 | オフライン状態を視覚的に表示 |
| NF-021 | 同期状態表示 | 同期中/完了/エラーの状態表示 |
| NF-022 | ローディング表示 | 長時間操作時のプログレス表示 |

### 3.4 互換性
| ID | 要件 | 説明 |
|----|------|------|
| NF-030 | macOS | macOS 12.0 (Monterey) 以降 |
| NF-031 | iOS | iOS 15.0 以降 |
| NF-032 | 将来: Windows | Windows 10 以降 |
| NF-033 | 将来: Android | Android 8.0 (API 26) 以降 |

---

## 4. 技術スタック

### 4.1 フロントエンド
| 項目 | 技術 | 理由 |
|------|------|------|
| フレームワーク | Flutter 3.x | クロスプラットフォーム対応、単一コードベース |
| 言語 | Dart | Flutter標準 |
| 状態管理 | Riverpod | 軽量でテスタブル |
| ローカルDB | Isar | 高速、軽量、オフライン対応 |

### 4.2 バックエンド
| 項目 | 技術 | 理由 |
|------|------|------|
| BaaS | Supabase | 認証/DB/リアルタイム同期を統合提供 |
| データベース | PostgreSQL (Supabase) | Supabase標準 |
| 認証 | Supabase Auth | OAuth対応、簡単な実装 |

### 4.3 AI
| 項目 | 技術 | 理由 |
|------|------|------|
| AIモデル | TBD（Gemini等） | 文章編集を低遅延で実行 |
| SDK | google_generative_ai（候補） | ユーザーAPIキーで文章編集を実行 |

### 4.4 主要パッケージ
```yaml
dependencies:
  flutter_riverpod: ^2.4.0      # 状態管理
  isar: ^3.1.0                  # ローカルDB
  supabase_flutter: ^2.0.0      # Supabase統合
  flutter_markdown: ^0.6.0      # Markdown表示
  google_generative_ai: ^0.2.0  # AI文章編集（候補）
  hotkey_manager: ^0.2.0        # グローバルホットキー
  flutter_secure_storage: ^9.0.0 # セキュアストレージ
  connectivity_plus: ^5.0.0     # ネットワーク状態監視
```

---

## 5. アーキテクチャ概要

### 5.1 レイヤー構成
```
┌─────────────────────────────────────┐
│           UI Layer                  │
│   (Widgets, Screens, Components)    │
├─────────────────────────────────────┤
│        State Layer                  │
│   (Riverpod Providers/Notifiers)    │
├─────────────────────────────────────┤
│       Service Layer                 │
│  ┌─────────────────────────────────┐│
│  │ NoteService    │ AIService      ││
│  │ SyncService    │ ShortcutService││
│  │ AuthService    │                ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│       Repository Layer              │
│  ┌─────────────────────────────────┐│
│  │ NoteRepository                  ││
│  │ UserRepository                  ││
│  └─────────────────────────────────┘│
├─────────────────────────────────────┤
│        Data Layer                   │
│  ┌───────────────┬─────────────────┐│
│  │ Local (Isar)  │ Remote (Supabase)│
│  └───────────────┴─────────────────┘│
└─────────────────────────────────────┘
```

### 5.2 ディレクトリ構造
```
lib/
├── main.dart
├── app.dart
├── core/
│   ├── config/           # 設定・定数
│   ├── errors/           # エラーハンドリング
│   └── utils/            # ユーティリティ
├── data/
│   ├── datasources/      # ローカル/リモートデータソース
│   ├── models/           # データモデル
│   └── repositories/     # リポジトリ実装
├── domain/
│   ├── entities/         # ドメインエンティティ
│   └── repositories/     # リポジトリインターフェース
├── presentation/
│   ├── providers/        # Riverpod providers
│   ├── screens/          # 画面
│   ├── widgets/          # 再利用可能なウィジェット
│   └── theme/            # テーマ設定
└── services/
    ├── ai_service.dart
    ├── sync_service.dart
    └── shortcut_service.dart
```

---

## 6. Supabaseスキーマ案

### 6.1 テーブル設計

#### users（Supabase Auth連携）
```sql
-- Supabase Authが自動生成するauth.usersを使用
-- 追加のプロフィール情報が必要な場合:
CREATE TABLE public.profiles (
  id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  display_name TEXT,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  updated_at TIMESTAMPTZ DEFAULT NOW()
);
```

#### notes
```sql
CREATE TABLE public.notes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  title TEXT NOT NULL DEFAULT '',
  content TEXT NOT NULL DEFAULT '',
  is_deleted BOOLEAN DEFAULT FALSE,  -- 論理削除
  local_updated_at TIMESTAMPTZ NOT NULL,  -- クライアントでの更新時刻
  server_updated_at TIMESTAMPTZ DEFAULT NOW(),  -- サーバー時刻で更新（端末時計ズレ対策）
  created_at TIMESTAMPTZ DEFAULT NOW(),

  -- 同期用メタデータ
  sync_version INTEGER DEFAULT 1,
  client_id TEXT  -- 競合解決用のクライアント識別子
);

-- インデックス
CREATE INDEX idx_notes_user_id ON public.notes(user_id);
CREATE INDEX idx_notes_updated ON public.notes(server_updated_at);
CREATE INDEX idx_notes_sync ON public.notes(user_id, server_updated_at);
```

### 6.2 Row Level Security (RLS)
```sql
-- notes テーブルのRLS
ALTER TABLE public.notes ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view own notes"
  ON public.notes FOR SELECT
  USING (auth.uid() = user_id);

CREATE POLICY "Users can insert own notes"
  ON public.notes FOR INSERT
  WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update own notes"
  ON public.notes FOR UPDATE
  USING (auth.uid() = user_id);
```

### 6.3 リアルタイム同期
```sql
-- リアルタイム通知の有効化
ALTER PUBLICATION supabase_realtime ADD TABLE public.notes;
```

---

## 7. 同期戦略

### 7.1 基本方針
- ログインなし（ゲスト）: ローカルのみで完結（同期しない）
- ログインあり: Supabaseとデバイス間同期
- 初期同期: 同期を有効化した時、既存ローカルメモをクラウドへ自動取り込み
- 保存確定: 同期ON時は自動でクラウド同期
- **Last Write Wins (LWW)** を基本戦略とする
- 最新判定は `server_updated_at` を基準（端末時計ズレ対策）
- 競合が発生した場合は同期時にローカル/クラウドの選択を促す
- 削除済みメモは14日経過後に完全削除（パージ）

### 7.2 同期フロー
```
[アプリ起動]
    ↓
[ローカルDBから読み込み]
    ↓
[オンライン確認]
    ↓ (オンライン)
[差分同期: local_updated_at > last_sync_at のメモを送信]
    ↓
[サーバーから更新を受信]
    ↓
[競合検出 → 解決]
    ↓
[ローカルDBに反映]
```

---

## 8. UI/UX（後日決定）

- クイック起動後は入力欄にフォーカスし、即入力できる状態にする
- （iOS）クイック起動の導線はOS制約に合わせて決定（TODO）
- （macOS）ウィンドウを閉じてもアプリは終了せずバックグラウンド常駐する（クイック起動で復帰）
- ダークモード対応
- テーマカラー選択
- フォントサイズ調整
- レイアウト（リスト/グリッド）

---

## 9. 変更履歴

| 日付 | バージョン | 変更内容 |
|------|-----------|---------|
| 2026-01-05 | 1.0.0 | 初版作成 |
| 2026-01-05 | 1.0.1 | MVP方針（AI/認証/クイック起動）を反映 |
| 2026-01-05 | 1.0.2 | クイック起動の挙動/初期同期/AIキー方式を確定 |
| 2026-01-05 | 1.0.3 | iOSクイック起動の導線表現を調整 |
| 2026-01-05 | 1.0.4 | Supabase方針（論理削除/サーバー時刻）を明確化 |
| 2026-01-05 | 1.0.5 | macOSクイック起動（表示/非表示）と常駐の仕様を追記 |
