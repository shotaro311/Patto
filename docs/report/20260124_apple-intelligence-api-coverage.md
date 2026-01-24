# Apple Intelligence（macOS）で Patto の現状AI機能を代替できるか（調査レポート）

作成日: 2026-01-24（JST） [S6]

注: 指定された `assets/report_template.md` がリポジトリ内で見つからなかったため、既存の `docs/report/` 配下のレポート形式に寄せつつ、依頼の評価軸（実装可否・可用性・条件・課金・フォールバック・実機テスト条件）に沿って構成しました。 [docs/report/20260119_hotkey-paste-report.md](20260119_hotkey-paste-report.md)

## 0. 調査対象（Pattoの現状AI I/O）

Patto は現状 `lib/services/ai_service.dart` で Google Generative AI を利用し、(1) `editText(instruction, originalText) -> editedText` と (2) `suggestTags(text, existingTags) -> tags[]` を提供しています。 [../../lib/services/ai_service.dart](../../lib/services/ai_service.dart)

本レポートは「macOS で Apple Intelligence の公式API（＝Appleが提供する公式SDK/フレームワーク）に置き換え可能か」を一次情報中心に判定します（iOSは後続として補足のみ）。 [S1]

## 1. 結論（実装可否の判定）

- **文章編集（instruction + originalText -> editedText）: 置き換え可能（条件付き）**。Foundation Models framework の `LanguageModelSession` に「指示（instructions）」＋「本文」を入力し、生成結果（`response.content`）を編集後テキストとして扱えます。 [S4]
- **タグ提案（text + existingTags -> tags[]）: 置き換え可能（条件付き）**。Foundation Models framework の「content tagging」用の built-in use case（`.contentTagging`）は、タグ生成・エンティティ抽出・トピック検出の一次サポートがあるため、Patto のタグ提案I/Oに寄せた実装が可能です（結果は後段で既存タグ除外などの正規化が必要）。 [S2]
- **ただし “全ユーザー/全環境で常に代替” は不可**。Apple Intelligence は「対応デバイス・対応OS・言語/地域・ユーザー設定（ON/OFF）・モデル準備状態」に依存し、利用不可のケースが公式に想定されています（`SystemLanguageModel.availability` で理由つきで判定）。そのため Patto では **フォールバック設計（外部AIへ切替 or 機能無効）** が現実的に必要です。 [S4]
- **課金は原則なし（推定ではなく一次情報ベース）**。Foundation Models framework はオンデバイスで動作し、Apple Newsroom は「AI inference が free of cost」と明記しています（＝従量課金型のAPI利用料は発生しない前提）。 [S5]

## 2. 優先度1: Apple Intelligenceに開発者向け「テキスト生成/編集」APIはあるか

Appleは Apple Intelligence のオンデバイスLLMへ「直接アクセス」できる公式の **Foundation Models framework** を提供しています。 [S1]

開発者は Swift で `import FoundationModels` し、`LanguageModelSession` を作って `respond(to:)` でテキスト生成（＝編集を含む）を行えます。 [S4]

`LanguageModelSession` には「セッション共通の指示（instructions）」を渡せるため、Patto の `editText(instruction, originalText)` の “instruction” をここ（またはプロンプト）に反映して、出力を `editedText` として扱う実装ができます。 [S4]

最小イメージ（公式サンプルの構造に沿った例）: [S4]
```swift
import FoundationModels

let instructions = """
You are a writing assistant.
Follow the user's instruction and return only the edited text.
"""
let session = LanguageModelSession(instructions: instructions)
let prompt = """
Instruction:
<user instruction here>

Text:
<original text here>
"""
let response = try await session.respond(to: prompt)
let editedText = response.content
```

## 3. 優先度2: Apple Intelligenceに「分類/タグ付け/要約」的なAPIはあるか

Foundation Models framework には “built-in specialized use cases backed by adapters” があり、その一つとして **content tagging** が公式に紹介されています。 [S2]

WWDC25セッションでは content tagging adapter が **tag generation / entity extraction / topic detection** を “first class support” すると明言され、`SystemLanguageModel(useCase: .contentTagging)` を `LanguageModelSession` に渡すコード例も提示されています。 [S2]

Patto の `suggestTags(text, existingTags)` に寄せるなら、`@Generable` で `topics: [String]` のような型を定義し、`respond(... generating: Result.self)` で **配列として構造化して受け取る**のが公式の推奨パスです（JSON文字列パースより堅牢）。 [S2]

実装イメージ（公式セッションの構造に沿った例）: [S2]
```swift
import FoundationModels

@Generable
struct Result {
  let topics: [String]
}

let session = LanguageModelSession(
  model: SystemLanguageModel(useCase: .contentTagging),
  instructions: "Suggest 1-7 short tags. Do not include existing tags."
)
let response = try await session.respond(to: text, generating: Result.self)
let tags = response.content.topics
```

補足: Appleが説明するオンデバイス基盤モデルは “3B parameter / 2-bit quantized / device-scale” で、要約・抽出・分類などのタスクに最適化され、世界知識や複雑な推論には向かない前提が述べられています（＝編集/タグ提案は適合しやすいが、品質評価は別途必要）。 [S2]

## 4. 可用性（公開/非公開/ベータ/制約）と対応OS

Foundation Models framework は、Apple Newsroom によると **iOS 26 / iPadOS 26 / macOS 26** で利用でき、Apple Intelligence 対応デバイスで Apple Intelligence が有効な場合に動作します。 [S5]

また同記事は Apple Intelligence を “available in beta” と記載しており、OS 26で利用可能でも挙動/品質が将来変わり得る前提での設計・検証が必要です。 [S5]

Patto が macOS 26 未満（例: macOS Sequoia 15.x 等）もサポートする場合、Foundation Models framework を前提に “完全置換” はできないため、外部AIや別方式のフォールバックが必要です。 [S5]

Apple Support の「How to get Apple Intelligence」には、対応デバイス（例: Mac は M1以降）や必要OS、設定での有効化、モデルダウンロード（ストレージ要件）など “利用条件” が明確に示されています。 [S6]

開発者向けにも「利用不可の端末がある」ことが前提になっており、公式のコードアロングは `SystemLanguageModel.availability` の `deviceNotEligible / appleIntelligenceNotEnabled / modelNotReady` などの分岐例と、利用不可時のフォールバックの重要性を記載しています。 [S4]

WWDCでは、ガードレール違反・未対応言語・コンテキストウィンドウ超過などの失敗ケース（エラー）をアプリ側でハンドルする必要があることも示されています。 [S3]

開発者フォーラム（Apple DTS Engineer回答）でも、(a) 実機/OS 26 で Apple Intelligence 有効、(b) シミュレータ利用時は “ホストMac側” が macOS 26 かつ Apple Intelligence 有効、(c) 言語/地域がサポート範囲、(d) availabilityチェック必須、がチェックリストとして示されています。 [S12]

追加の制約として、同フォーラムでは「シミュレータは macOS 上のモデル資産を使うため、macOS 15.5 にはモデルがない」「Apple Intelligence は VM 上で動作しない」などが明言されています。 [S12]

## 5. 利用条件（オンデバイス / Private Cloud Compute 等）と課金の有無

Appleは Apple Intelligence を「オンデバイス処理が基本」で、より複雑なリクエストでは **Private Cloud Compute（PCC）** を使い得る、と説明しています。 [S7]

PCC の仕組み（データ非保存、リクエスト遂行のみに利用、検証可能性など）は Apple Security Research が詳細に公開しており、Apple Support でも端末から PCC に送られたリクエストのレポート生成に触れています。 [S8]

Appleのプライバシー開示（intelligence-engine）では、例として Writing Tools の校正・編集が PCC に送られる場合があることを明示しています。 [S9]

ただし **Foundation Models framework 自体はオンデバイスのLLMへアクセスするフレームワーク**として説明されており、Apple Newsroom は「available offline」「AI inference that is free of cost」と述べています（＝少なくとも “開発者がPCCに課金APIとして叩く” 形ではない）。 [S5]

未検証: Foundation Models framework のリクエストが条件により PCC にルーティングされるかどうかは、一次情報（公開ドキュメント）として本調査では確認できませんでした（少なくとも公式の紹介は “on-device” が主）。 [S1]

## 6. ルール/ガードレール（利用規約・安全性）

Apple Developer は Foundation Models framework の **Acceptable use requirements** を公開しており、禁止用途（違法行為、暴力、ポルノ、詐欺、規制対象領域など）やガードレール回避の禁止等を明記しています。 [S10]

開発者は、モデル出力の安全性・ユーザー体験（ガードレール違反や言語未対応などのエラー）を考慮した設計とハンドリングが必要だとWWDCセッションでも説明されています。 [S2]

## 7. 優先度3: 直接APIが無い場合の代替候補と限界（比較）

前提として、今回の2機能は Foundation Models framework により “直接” 実装できる可能性が高いですが、**未対応端末/未対応OSのための代替**は別途必要になります。 [S4]

### 7.1 Writing Tools

Writing Tools は Apple Intelligence のユーザー向け機能として提供されていますが、少なくとも本調査範囲の一次情報では「アプリが `instruction + text -> editedText` をAPIで呼び出して結果を取得する」形の開発者向けAPIとしては確認できません（ユーザー操作/システムUI中心の機能）。 [S6]

### 7.2 App Intents / Shortcuts

Apple Intelligence は Shortcuts（ショートカット）に “intelligent actions” や “Use Apple Intelligence models in Shortcuts” を提供していますが、Patto のアプリ内ロジックとして同期的に `editText` / `suggestTags` を提供する用途の代替にはなりにくいです（ユーザーがショートカットを実行する前提になりやすい）。 [S6]

### 7.3 NaturalLanguage（タグ抽出の代替候補）

Natural Language framework は、トークナイズ、品詞/固有表現抽出、言語判定、埋め込み等のNLP機能を提供します。 [S13]

そのため「LLMで自然言語から柔軟にタグ候補を生成する」代わりに、キーワード抽出/固有表現抽出/類似度計算などで **限定的なタグ提案**を実装する余地はありますが、出力の自由度や表現力は generative model より一般に低くなります（“編集文生成” の代替にはならない）。 [S13]

### 7.4 Create ML / Core ML（固定ラベル分類の代替候補）

Create ML では “テキスト分類モデル” をトレーニングし、自然言語テキストをラベルへ分類できます。 [S14]

ただしこの方式は「タグ集合が固定・学習済みである」ことが前提になりやすく、Patto のように既存タグの入力に応じて柔軟に提案を変える用途では、タグの増減やドメイン変化への追随（再学習・配布）がボトルネックになり得ます。 [S14]

## 8. 優先度4: フォールバック設計の必要性（根拠）

必要性の根拠は大きく3つです: (1) 対応デバイス要件（例: Mac は M1以降）、(2) Apple Intelligence の設定OFF/モデル未準備、(3) 言語/地域の制約（中国本土などの制限も明示）。 [S6]

公式サンプルは availability を確認し、利用不可時に “graceful fallback” を行うことを明記しているため、Patto 側でも `SystemLanguageModel.availability` をゲートにした分岐（オンデバイスAI→外部AI→機能停止/案内）を設計するのが妥当です。 [S4]

## 9. 優先度5: 実機テストに必要な条件（macOS中心）

Apple Support では、Apple Intelligence を使うには「対応デバイス」「必要OS」「設定で Apple Intelligence をON」「モデルダウンロード（ストレージ）」などが必要だと説明しています。 [S6]

開発者フォーラム（Apple DTS Engineer回答）では、Foundation Models framework を使う前提として「OS 26」「Apple Intelligence 有効」「（シミュレータ利用時）ホストMacが macOS 26 かつ Apple Intelligence 有効」「言語/地域がサポート範囲」「availabilityチェック」を挙げています。 [S12]

同フォーラムでは追加で「Apple Intelligence は VM では動作しない」「（少なくとも当時）シミュレータはホストmacOSのモデルに依存する」こと、さらに “外部ボリューム起動では Apple Intelligence が利用不可” になり得る事例が共有されています（＝**実機 + 内蔵ボリューム起動**で検証するのが安全）。 [S12]

## 10. 参考（実装メモ：Flutter/Pattoへの統合観点）

Patto は Flutter アプリのため、macOS側は Swift（Runner）で Foundation Models framework を呼び、MethodChannel 等で Dart に橋渡しする実装が現実的です（この“橋渡し”自体はApple公式資料ではなく、Flutterの一般的な統合手法です）。 [S4]

コミュニティでは Flutter から Foundation Models framework を扱うためのパッケージやサンプル実装が公開されていますが、対応OSなどは一次情報での再確認が必要です（参考扱い）。 [C1]

## 11. 参考リンク（一次情報中心）

- Foundation Models framework（Apple Intelligence / What’s new）: [S1]
- WWDC25: Meet the Foundation Models framework: [S2]
- WWDC25: Deep dive into the Foundation Models framework: [S3]
- Meet with Apple: Foundation Models Code-Along Instructions（コード/availability例）: [S4]
- Apple Newsroom: Foundation Models framework unlocks new app experiences: [S5]
- Apple Support: How to get Apple Intelligence（対応端末/OS/言語/地域/設定/ストレージ）: [S6]
- Apple: Apple Intelligence（オンデバイス + PCCの説明）: [S7]
- Apple Security Research: Private Cloud Compute（技術詳細）: [S8]
- Apple Legal: Apple Intelligence & Privacy（PCCへ送る例など）: [S9]
- Apple Developer: Acceptable use requirements for the Foundation Models framework: [S10]
- Apple Developer: Adapter training toolkit（アダプターとエンタイトルメント）: [S11]
- Apple Developer Forums: Foundation Model Framework（VM/シミュレータ等の実運用の注意）: [S12]
- Apple Developer Documentation: Natural Language framework: [S13]
- Apple Developer Documentation: Create ML（テキスト分類モデルの作成）: [S14]

## 12. 参考リンク（コミュニティ / 補助情報）

- Pub.dev: `foundation_models_framework`（Flutter向けラッパー）: [C1]
- GitHub: flutter_foundation_models_framework（Flutter向け実装例）: [C2]
- Zenn: Foundation Models frameworkでチャットアプリ実装（入門例）: [C3]

---

[S1]: https://developer.apple.com/apple-intelligence/whats-new/
[S2]: https://developer.apple.com/videos/play/wwdc2025/286/
[S3]: https://developer.apple.com/videos/play/wwdc2025/301/
[S4]: https://developer.apple.com/events/resources/code-along-205/
[S5]: https://www.apple.com/cm/newsroom/2025/09/apples-foundation-models-framework-unlocks-new-intelligent-app-experiences/
[S6]: https://support.apple.com/en-us/121115
[S7]: https://www.apple.com/apple-intelligence/
[S8]: https://security.apple.com/com/blog/private-cloud-compute/
[S9]: https://www.apple.com/legal/privacy/data/en/intelligence-engine/
[S10]: https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/
[S11]: https://developer.apple.com/apple-intelligence/foundation-models-adapter/
[S12]: https://developer.apple.com/forums/thread/787445
[S13]: https://developer.apple.com/documentation/naturallanguage
[S14]: https://developer.apple.com/jp/documentation/createml/creating_a_text_classifier_model/

[C1]: https://pub.dev/documentation/foundation_models_framework/latest/
[C2]: https://github.com/dmakwt/flutter_foundation_models_framework
[C3]: https://zenn.dev/5enxia/articles/2061169fff00cd
