import Flutter
import UIKit

#if canImport(FoundationModels)
import FoundationModels
#endif

final class AppleIntelligenceBridge {
  private enum ErrorCode {
    static let notSupported = "not_supported"
    static let badArgs = "bad_args"
    static let notAvailable = "not_available"
    static let aiFailed = "ai_failed"
    static let emptyResponse = "empty_response"
    static let refused = "refused"
    static let invalidFormat = "invalid_format"
  }

  private enum ErrorMessage {
    static let notSupported = "Apple IntelligenceはiOS 18.0以降が必要です"
    static let badArgs = "引数が不正です"
    static let notAvailable = "Apple Intelligenceが利用できません"
    static let emptyResponse = "Apple Intelligenceから応答がありませんでした"
    static let refused = "Apple Intelligenceがこのリクエストを拒否しました"
    static let invalidTagsResponse = "タグの応答形式が不正です"
    static let noJsonFound = "JSON形式の応答が見つかりませんでした"
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkAvailability":
      result(["status": availabilityStatus()])
    case "editText":
      handleEditText(call: call, result: result)
    case "suggestTags":
      handleSuggestTags(call: call, result: result)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func handleEditText(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 18.0, *) else {
      result(FlutterError(code: ErrorCode.notSupported, message: ErrorMessage.notSupported, details: nil))
      return
    }
    guard let args = call.arguments as? [String: Any],
          let instruction = args["instruction"] as? String,
          let text = args["text"] as? String else {
      result(FlutterError(code: ErrorCode.badArgs, message: ErrorMessage.badArgs, details: nil))
      return
    }
    guard availabilityStatus() == "available" else {
      result(FlutterError(code: ErrorCode.notAvailable, message: ErrorMessage.notAvailable, details: nil))
      return
    }
    runTask(result: result) {
      try await self.editText(instruction: instruction, text: text)
    }
  }

  private func handleSuggestTags(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard #available(iOS 18.0, *) else {
      result(FlutterError(code: ErrorCode.notSupported, message: ErrorMessage.notSupported, details: nil))
      return
    }
    guard let args = call.arguments as? [String: Any],
          let text = args["text"] as? String else {
      result(FlutterError(code: ErrorCode.badArgs, message: ErrorMessage.badArgs, details: nil))
      return
    }
    let existingTags = args["existingTags"] as? [String] ?? []
    let dictionaryTags = args["dictionaryTags"] as? [String] ?? []
    guard availabilityStatus() == "available" else {
      result(FlutterError(code: ErrorCode.notAvailable, message: ErrorMessage.notAvailable, details: nil))
      return
    }
    runTask(result: result) {
      try await self.suggestTags(text: text, existingTags: existingTags, dictionaryTags: dictionaryTags)
    }
  }

  private func availabilityStatus() -> String {
#if canImport(FoundationModels)
    if #available(iOS 18.0, *) {
      let model = SystemLanguageModel.default
      switch model.availability {
      case .available:
        return "available"
      case .unavailable(.deviceNotEligible):
        return "notEligible"
      case .unavailable(.appleIntelligenceNotEnabled):
        return "notEnabled"
      case .unavailable(.modelNotReady):
        return "modelNotReady"
      case .unavailable:
        return "notAvailable"
      }
    }
#endif
    return "notSupported"
  }

  private func runTask<T>(result: @escaping FlutterResult, operation: @escaping () async throws -> T) {
    Task {
      do {
        let value = try await operation()
        DispatchQueue.main.async { result(value) }
      } catch let error as NSError {
        DispatchQueue.main.async {
          let code = error.userInfo["code"] as? String ?? ErrorCode.aiFailed
          result(FlutterError(code: code, message: error.localizedDescription, details: nil))
        }
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: ErrorCode.aiFailed, message: "AI処理中にエラーが発生しました", details: nil))
        }
      }
    }
  }

#if canImport(FoundationModels)
  @available(iOS 18.0, *)
  private func editText(instruction: String, text: String) async throws -> String {
    let instructions = [
      "You are a writing assistant.",
      "Follow the user's instruction and return only the edited text.",
      "Do not add any explanation or preamble."
    ].joined(separator: " ")
    let session = LanguageModelSession(instructions: instructions)
    let prompt = "Instruction:\n\(instruction)\n\nText:\n\(text)"
    let response = try await session.respond(to: prompt)
    let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      throw NSError(domain: "AppleIntelligence", code: 1, userInfo: [
        NSLocalizedDescriptionKey: ErrorMessage.emptyResponse,
        "code": ErrorCode.emptyResponse
      ])
    }
    if isRefusalResponse(trimmed) {
      throw NSError(domain: "AppleIntelligence", code: 4, userInfo: [
        NSLocalizedDescriptionKey: ErrorMessage.refused,
        "code": ErrorCode.refused
      ])
    }
    return trimmed
  }

  @available(iOS 18.0, *)
  private func suggestTags(text: String, existingTags: [String], dictionaryTags: [String]) async throws -> [String] {
    let existing = Set(existingTags
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty })
    let dictionary = dictionaryTags
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
      .filter { !$0.isEmpty && !existing.contains($0) }
    let limitedDictionary = Array(dictionary.prefix(120))
    let rule = existing.isEmpty
      ? "Suggest 1-5 short tags."
      : "Suggest 1-5 short tags. Do not include existing tags: \(Array(existing).joined(separator: ", "))."
    let dictionaryRule = limitedDictionary.isEmpty
      ? "If no dictionary tag fits, create a new short tag."
      : "Prefer dictionary tags when they fit the text. Only create a new tag if no dictionary tag fits."
    let instructions = [
      "You are a tagging assistant.",
      "Return JSON only: {\"tags\":[\"tag1\",\"tag2\"]}.",
      "No extra text.",
      rule,
      dictionaryRule
    ].joined(separator: " ")
    let session = LanguageModelSession(instructions: instructions)
    let prompt = limitedDictionary.isEmpty
      ? "Text:\n\(text)"
      : """
Text:
\(text)

Dictionary tags:
\(limitedDictionary.joined(separator: ", "))
"""
    let response = try await session.respond(to: prompt)
    let jsonText = try extractJsonObject(from: response.content)
    let data = jsonText.data(using: .utf8) ?? Data()
    let object = try JSONSerialization.jsonObject(with: data)
    guard let dict = object as? [String: Any],
          let tags = dict["tags"] as? [String] else {
      throw NSError(domain: "AppleIntelligence", code: 2, userInfo: [
        NSLocalizedDescriptionKey: ErrorMessage.invalidTagsResponse,
        "code": ErrorCode.invalidFormat
      ])
    }
    return Array(tags.prefix(5))
  }

  private func extractJsonObject(from raw: String) throws -> String {
    guard let start = raw.firstIndex(of: "{"),
          let end = raw.lastIndex(of: "}") else {
      throw NSError(domain: "AppleIntelligence", code: 3, userInfo: [
        NSLocalizedDescriptionKey: ErrorMessage.noJsonFound,
        "code": ErrorCode.invalidFormat
      ])
    }
    return String(raw[start...end])
  }

  private static let refusalPatterns: [String] = [
    // English patterns
    "i'm sorry",
    "i am sorry",
    "i can't assist",
    "i cannot assist",
    "i can't help",
    "i cannot help",
    "i'm unable",
    "i am unable",
    "sorry, but i can't",
    "sorry, but i cannot",
    "i'm not able",
    "i am not able",
    "as an ai",
    "as a language model",
    // Japanese patterns
    "申し訳",
    "お手伝いできません",
    "対応できません",
    "できかねます",
    "お応えできません",
    "お答えできません",
    "サポートできません",
    "ご要望にお応えできません",
    "aiとして",
    "言語モデルとして"
  ]

  private func isRefusalResponse(_ text: String) -> Bool {
    let lowered = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    return Self.refusalPatterns.contains { lowered.contains($0) }
  }
#endif
}
