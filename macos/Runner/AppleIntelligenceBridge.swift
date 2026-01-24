import Cocoa
import FlutterMacOS

#if canImport(FoundationModels)
import FoundationModels
#endif

final class AppleIntelligenceBridge {
  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkAvailability":
      result(["status": availabilityStatus()])
    case "editText":
      guard #available(macOS 26.0, *) else {
        result(FlutterError(code: "not_supported", message: "Apple Intelligence requires macOS 26.0 or newer.", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let instruction = args["instruction"] as? String,
            let text = args["text"] as? String else {
        result(FlutterError(code: "bad_args", message: "Invalid arguments.", details: nil))
        return
      }
      guard availabilityStatus() == "available" else {
        result(FlutterError(code: "not_available", message: "Apple Intelligence not available.", details: nil))
        return
      }
      runTask(result: result) {
        try await self.editText(instruction: instruction, text: text)
      }
    case "suggestTags":
      guard #available(macOS 26.0, *) else {
        result(FlutterError(code: "not_supported", message: "Apple Intelligence requires macOS 26.0 or newer.", details: nil))
        return
      }
      guard let args = call.arguments as? [String: Any],
            let text = args["text"] as? String else {
        result(FlutterError(code: "bad_args", message: "Invalid arguments.", details: nil))
        return
      }
      let existingTags = args["existingTags"] as? [String] ?? []
      guard availabilityStatus() == "available" else {
        result(FlutterError(code: "not_available", message: "Apple Intelligence not available.", details: nil))
        return
      }
      runTask(result: result) {
        try await self.suggestTags(text: text, existingTags: existingTags)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func availabilityStatus() -> String {
#if canImport(FoundationModels)
    if #available(macOS 26.0, *) {
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
      } catch {
        DispatchQueue.main.async {
          result(FlutterError(code: "ai_failed", message: error.localizedDescription, details: nil))
        }
      }
    }
  }

#if canImport(FoundationModels)
  @available(macOS 26.0, *)
  private func editText(instruction: String, text: String) async throws -> String {
    let instructions = [
      "You are a writing assistant.",
      "Follow the user's instruction and return only the edited text."
    ].joined(separator: " ")
    let session = LanguageModelSession(instructions: instructions)
    let prompt = "Instruction:\\n\\(instruction)\\n\\nText:\\n\\(text)"
    let response = try await session.respond(to: prompt)
    let trimmed = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
    if trimmed.isEmpty {
      throw NSError(domain: "AppleIntelligence", code: 1, userInfo: [
        NSLocalizedDescriptionKey: "Empty response."
      ])
    }
    return trimmed
  }

  @available(macOS 26.0, *)
  private func suggestTags(text: String, existingTags: [String]) async throws -> [String] {
    let existing = existingTags
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .filter { !$0.isEmpty }
    let rule = existing.isEmpty
      ? "Suggest 1-7 short tags."
      : "Suggest 1-7 short tags. Do not include existing tags: \\(existing.joined(separator: \", \"))."
    let instructions = [
      "You are a tagging assistant.",
      "Return JSON only: {\\\"tags\\\":[\\\"tag1\\\",\\\"tag2\\\"]}.",
      "No extra text.",
      rule
    ].joined(separator: " ")
    let session = LanguageModelSession(instructions: instructions)
    let response = try await session.respond(to: text)
    let jsonText = try extractJsonObject(from: response.content)
    let data = jsonText.data(using: .utf8) ?? Data()
    let object = try JSONSerialization.jsonObject(with: data)
    guard let dict = object as? [String: Any],
          let tags = dict["tags"] as? [String] else {
      throw NSError(domain: "AppleIntelligence", code: 2, userInfo: [
        NSLocalizedDescriptionKey: "Invalid tags response."
      ])
    }
    return tags
  }

  private func extractJsonObject(from raw: String) throws -> String {
    guard let start = raw.firstIndex(of: "{"),
          let end = raw.lastIndex(of: "}") else {
      throw NSError(domain: "AppleIntelligence", code: 3, userInfo: [
        NSLocalizedDescriptionKey: "No JSON object found."
      ])
    }
    return String(raw[start...end])
  }
#endif
}
