import Foundation
import LiteRTLM

/// Runs Gemma on device through LiteRT-LM and streams the decoded text back token by token.
actor LiteRtLmEngine {

  private let modelStore = ModelStore()
  private let cancellable = CancellableConversation()

  private var engine: Engine?
  private var conversation: Conversation?

  /// Downloads the weights if needed and initializes the engine. Both steps are slow enough that
  /// this must stay off the main thread.
  func load() async throws {
    if conversation != nil { return }

    let modelFile = try await modelStore.resolveModelFile()
    let created = Engine(engineConfig: try HardwareAccelerator.engineConfig(modelFile: modelFile))
    try await created.initialize()

    let started = try await created.createConversation(
      with: try Self.conversationConfig(history: [])
    )
    conversation = started
    engine = created
    cancellable.use(started)
  }

  /// Streams a reply to `prompt`.
  ///
  /// The native conversation holds its own KV cache, so the usual turn only sends the new prompt.
  /// When `resetContext` is set, the conversation is rebuilt from `history` instead, which is how
  /// the caller enforces its context window.
  func generate(
    prompt: String,
    history: [Message],
    resetContext: Bool,
    onToken: @escaping @Sendable (String) -> Void
  ) async throws {
    let active = try await activeConversation(history: history, resetContext: resetContext)

    for try await chunk in active.sendMessageStream(Message(prompt)) {
      // A superseded prompt must not append to the reply the newer one is already streaming.
      try Task.checkCancellation()
      for content in chunk.contents {
        if case .text(let text) = content, !text.isEmpty {
          onToken(text)
        }
      }
    }

    // Cancelling right after the last chunk still has to stop the caller from sealing the reply.
    try Task.checkCancellation()
  }

  /// Stops the current decode. Harmless when nothing is running, and never waits on the actor so a
  /// new prompt can interrupt one that is still decoding.
  nonisolated func cancel() {
    cancellable.cancel()
  }

  private func activeConversation(
    history: [Message],
    resetContext: Bool
  ) async throws -> Conversation {
    guard let engine else {
      throw LiteRtLmEngineError.notLoaded
    }

    if resetContext {
      let rebuilt = try await engine.createConversation(
        with: try Self.conversationConfig(history: history)
      )
      conversation = rebuilt
      cancellable.use(rebuilt)
    }

    guard let conversation else {
      throw LiteRtLmEngineError.notLoaded
    }
    return conversation
  }

  private static func conversationConfig(history: [Message]) throws -> ConversationConfig {
    ConversationConfig(
      systemMessage: Message(systemInstruction, role: .system),
      initialMessages: history,
      samplerConfig: try SamplerConfig(topK: 40, topP: 0.95, temperature: 0.8)
    )
  }

  private static let systemInstruction =
    "You are Lumin, a concise and friendly assistant. Reply with plain text only."
}

/// Holds the conversation that `cancel` acts on.
///
/// `cancel` arrives on the platform thread while the engine actor is busy streaming, so the handle
/// it needs is kept behind a plain lock instead of actor isolation.
private final class CancellableConversation: @unchecked Sendable {

  private let lock = NSLock()
  private var conversation: Conversation?

  func use(_ conversation: Conversation?) {
    lock.lock()
    defer { lock.unlock() }
    self.conversation = conversation
  }

  func cancel() {
    lock.lock()
    let current = conversation
    lock.unlock()
    try? current?.cancel()
  }
}

enum LiteRtLmEngineError: LocalizedError {
  case notLoaded

  var errorDescription: String? {
    switch self {
    case .notLoaded:
      return "The model is not loaded."
    }
  }
}
