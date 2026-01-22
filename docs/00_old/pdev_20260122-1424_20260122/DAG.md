# Parallel Dev DAG

## DAG サマリー（ノードと依存）
> 形式: `TASK_ID: depends_on -> [ ... ]`

- T0: depends_on -> []（基盤）
- T1: depends_on -> [T0]
- T2: depends_on -> [T0]
- T3: depends_on -> [T1, T2]（統合・テスト）

## タスク一覧
### T0: 基盤（モデル/永続化/移行方針）
- 目的:
  - 既存の「SharedPreferences 1件下書き」から「複数下書き（Isar）」へ移行できる土台を作る
  - Noteメタデータ（manualTags/autoTags/links等）の永続化を可能にする
- 依存: []
- 並行可否: 不可（共有境界そのもの）
- SCOPE（変更対象）:
  - `lib/data/models/note.dart`
  - `lib/data/repositories/note_repository.dart`
  - `lib/presentation/providers/quick_memo_provider.dart`（置き換えのための下準備）
  - `lib/data/repositories/quick_memo_repository.dart`（廃止/移行）
- 共有境界:
  - DB（Isar schema）/ 同期対象の定義 / 既存UIの参照先
- 成果物:
  - ベースブランチへのコミット（T1/T2がrebaseできる状態）
- テスト/確認:
  - `flutter analyze`
  - macOSビルド（少なくともコンパイル）

### T1: 下書きInbox UI/フロー
- 目的:
-  - ホットキー起動時に新規下書きを開き、最近の下書きを再開できる
-  - 「保存（整理/確定）」で通常メモ扱いへし、入力欄が空に戻る
- 依存: [T0]
- 並行可否: 可（T0でデータ/APIが固まっている前提）
- SCOPE（変更対象）:
  - `lib/presentation/screens/quick_memo_screen.dart`
  - `lib/presentation/providers/quick_memo_provider.dart`
  - `lib/app.dart`（起動時に新規下書きを作る導線）
- 共有境界（触るなら基盤タスクへ）:
  - DBモデル/同期/設定項目
- 成果物:
  - PR または diff
- テスト/確認:
  - `flutter analyze`
  - 手動確認: ホットキー起動→新規下書き、保存→入力欄が空、最近下書きへ戻れる

### T2: 自動整理（タグ/リンク/AI提案）最小
- 目的:
  - `manualTags` と `autoTags` の分離を前提に、タグ候補を「提案」として提示できる
  - `[[リンク]]`等のリンク抽出（最小）で関連づけの土台を作る
- 依存: [T0]
- 並行可否: 可（T0でメタ永続化ができる前提）
- SCOPE（変更対象）:
  - `lib/data/models/note.dart`（T0で追加されたフィールドを利用）
  - `lib/services/ai_service.dart`（既存がある場合は拡張、無い場合は最小追加）
  - `lib/presentation/screens/note_editor_pane.dart`（提案UIの表示）
- 共有境界（触るなら基盤タスクへ）:
  - DBモデル/同期/設定項目
- 成果物:
  - PR または diff
- テスト/確認:
  - `flutter analyze`
  - 手動確認: タグ候補が表示され、適用で `autoTags` に反映される

### T3: 統合・テスト
- 目的:
  - T1/T2 を統合し、既存機能（編集/検索/同期/ホットキー）を壊さない
- 依存: [T1, T2]
- 並行可否: 不可
- SCOPE（変更対象）:
  - 影響範囲の調整（ルーティング/一覧/検索）
- テスト/確認:
  - `flutter analyze`
  - `flutter test`（存在する範囲）

（T2, T3... も同様に列挙）
